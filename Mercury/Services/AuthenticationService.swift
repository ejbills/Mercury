//
//  AuthenticationService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation
import AuthenticationServices
import Combine
import Defaults

@Observable
class AuthenticationService: NSObject, ASWebAuthenticationPresentationContextProviding {
    var apiStatus: APIStatus = .unknown
    var userInfo: RedditUser?
    var errorMessage: String?
    var accessToken: String?
    var refreshToken: String?
    var accessTokenExpiry: Date?
    
    private var clientId: String = ""
    private let redirectURI = "mercury://oauth"
    private var authSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshTimer: Timer?
    
    enum APIStatus {
        case unknown
        case validating
        case valid
        case invalid
        case networkError
    }
    
    override init() {
        super.init()
        loadStoredCredentials()
    }
    
    // MARK: - Configuration
    
    func setClientId(_ clientId: String) {
        self.clientId = clientId
        Defaults[.clientId] = clientId
        self.apiStatus = .unknown
        self.userInfo = nil
        self.errorMessage = nil
        self.accessToken = nil
    }
    
    // MARK: - Credential Management
    
    private func loadStoredCredentials() {
        self.clientId = Defaults[.clientId]
        self.accessToken = Defaults[.accessToken]
        self.refreshToken = Defaults[.refreshToken]
        self.accessTokenExpiry = Defaults[.accessTokenExpiry]
        self.userInfo = Defaults[.userInfo]
        
        if !clientId.isEmpty && accessToken != nil && userInfo != nil {
            self.apiStatus = .valid
            // If expired already, try to refresh immediately; otherwise schedule
            if isAccessTokenExpired(threshold: 0), refreshToken != nil {
                Task { _ = await self.refreshAccessToken() }
            } else {
                scheduleTokenRefreshIfNeeded()
            }
        }
    }
    
    private func saveCredentials() {
        Defaults[.clientId] = clientId
        Defaults[.accessToken] = accessToken
        Defaults[.refreshToken] = refreshToken
        Defaults[.accessTokenExpiry] = accessTokenExpiry
        Defaults[.userInfo] = userInfo
        Defaults[.isSetupComplete] = true
        Defaults[.lastLoginDate] = Date()
    }
    
    func clearStoredCredentials() {
        Defaults[.clientId] = ""
        Defaults[.accessToken] = nil
        Defaults[.refreshToken] = nil
        Defaults[.accessTokenExpiry] = nil
        Defaults[.userInfo] = nil
        Defaults[.isSetupComplete] = false
        Defaults[.lastLoginDate] = nil
        
        self.clientId = ""
        self.accessToken = nil
        self.refreshToken = nil
        self.accessTokenExpiry = nil
        self.userInfo = nil
        self.apiStatus = .unknown
        self.errorMessage = nil
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    var hasStoredCredentials: Bool {
        return !clientId.isEmpty && accessToken != nil && userInfo != nil
    }
    
    // MARK: - OAuth Flow
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    func startOAuthFlow() {
        guard !clientId.isEmpty else {
            self.apiStatus = .invalid
            self.errorMessage = "Client ID is required"
            return
        }
        
        print("🔑 Starting OAuth flow with client ID: \(clientId)")
        
        let state = UUID().uuidString
        // Full Reddit API permissions
        let scope = "identity,edit,flair,history,modconfig,modflair,modlog,modposts,modwiki,mysubreddits,privatemessages,read,report,save,submit,subscribe,vote,wikiedit,wikiread"
        
        var components = URLComponents(string: "https://www.reddit.com/api/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "duration", value: "permanent"),
            URLQueryItem(name: "scope", value: scope)
        ]
        
        guard let authURL = components.url else {
            self.apiStatus = .invalid
            self.errorMessage = "Failed to create authorization URL"
            return
        }
        
        print("🌐 OAuth URL: \(authURL.absoluteString)")
        
        self.apiStatus = .validating
        self.errorMessage = nil
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "mercury"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleAuthenticationResult(callbackURL: callbackURL, error: error)
            }
        }
        
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false // Changed to false for better debugging
        authSession?.start()
    }
    
    private func handleAuthenticationResult(callbackURL: URL?, error: Error?) {
        if let error = error {
            if let authError = error as? ASWebAuthenticationSessionError {
                switch authError.code {
                case .canceledLogin:
                    self.apiStatus = .unknown
                    self.errorMessage = "Authentication cancelled"
                default:
                    self.apiStatus = .invalid
                    self.errorMessage = "Authentication failed: \(authError.localizedDescription)"
                }
            } else {
                self.apiStatus = .invalid
                self.errorMessage = "Authentication error: \(error.localizedDescription)"
            }
            return
        }
        
        guard let callbackURL = callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            self.apiStatus = .invalid
            self.errorMessage = "Invalid authorization response"
            return
        }
        
        Task {
            await exchangeCodeForToken(code: code)
        }
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "https://www.reddit.com/api/v1/access_token") else {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = "Invalid token URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyData = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)".data(using: .utf8)
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.apiStatus = .invalid
                    self.errorMessage = "Failed to exchange authorization code"
                }
                return
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                // Store refresh token if provided (first grant)
                if let rt = tokenResponse.refreshToken {
                    self.refreshToken = rt
                }
                // Compute expiry if provided
                if let expiresIn = tokenResponse.expiresIn {
                    self.accessTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                }
            }
            
            await fetchUserInfo()
            
        } catch {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Validation
    
    func validateCredentials() async {
        guard !clientId.isEmpty else {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = "Client ID is required"
            }
            return
        }
        
        if accessToken == nil {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = "Please authenticate with Reddit first"
            }
            return
        }
        
        await fetchUserInfo()
    }
    
    private func fetchUserInfo() async {
        guard let accessToken = accessToken,
              let url = URL(string: "https://oauth.reddit.com/api/v1/me") else {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = "Missing access token"
            }
            return
        }
        
        // If token appears expired, attempt refresh before the request
        if isAccessTokenExpired(), let _ = refreshToken {
            _ = await refreshAccessToken()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.apiStatus = .networkError
                    self.errorMessage = "Network error"
                }
                return
            }
            
            if httpResponse.statusCode == 401 {
                // Try one token refresh and retry once
                let refreshed = await refreshAccessToken()
                if refreshed {
                    await fetchUserInfo()
                    return
                } else {
                    await MainActor.run {
                        self.apiStatus = .invalid
                        self.errorMessage = "Access token expired or invalid"
                    }
                    return
                }
            } else if httpResponse.statusCode != 200 {
                await MainActor.run {
                    self.apiStatus = .invalid
                    self.errorMessage = "Server error (HTTP \(httpResponse.statusCode))"
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let user = try decoder.decode(RedditUser.self, from: data)
            
            await MainActor.run {
                self.userInfo = user
                self.apiStatus = .valid
                self.saveCredentials()
                self.scheduleTokenRefreshIfNeeded()
            }
            
        } catch {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Token Refresh
    private func isAccessTokenExpired(threshold: TimeInterval = 60) -> Bool {
        guard let expiry = accessTokenExpiry else { return false }
        return Date().addingTimeInterval(threshold) >= expiry
    }
    
    private func scheduleTokenRefreshIfNeeded() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        guard let expiry = accessTokenExpiry, refreshToken != nil else { return }
        let interval = max(5, expiry.timeIntervalSinceNow - 60) // refresh 60s early, min 5s
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { _ = await self?.refreshAccessToken() }
        }
    }
    
    @discardableResult
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken, !clientId.isEmpty else { return false }
        guard let url = URL(string: "https://www.reddit.com/api/v1/access_token") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = "\(clientId):".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                if let newRT = tokenResponse.refreshToken { // Reddit may not return this on refresh
                    self.refreshToken = newRT
                }
                if let expiresIn = tokenResponse.expiresIn {
                    self.accessTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                }
                self.saveCredentials()
                self.scheduleTokenRefreshIfNeeded()
            }
            return true
        } catch {
            return false
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let refreshToken: String?
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct RedditUser: Codable, Defaults.Serializable {
    let name: String
    let linkKarma: Int
    let commentKarma: Int
    let created: Double
    let verified: Bool
    let hasVerifiedEmail: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case linkKarma
        case commentKarma
        case created
        case verified
        case hasVerifiedEmail
    }
    
    var totalKarma: Int {
        linkKarma + commentKarma
    }
    
    var accountAge: String {
        let createdDate = Date(timeIntervalSince1970: created)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdDate)
    }
}
