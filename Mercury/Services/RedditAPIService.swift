//
//  RedditAPIService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation
import AuthenticationServices
import Combine
import Defaults

@Observable
class RedditAPIService: NSObject, ASWebAuthenticationPresentationContextProviding {
    var apiStatus: APIStatus = .unknown
    var userInfo: RedditUser?
    var errorMessage: String?
    var accessToken: String?
    
    private var clientId: String = ""
    private let baseURL = "https://oauth.reddit.com"
    private let redirectURI = "mercury://oauth"
    private var authSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        loadStoredCredentials()
    }
    
    enum APIStatus {
        case unknown
        case validating
        case valid
        case invalid
        case networkError
    }
    
    func setClientId(_ clientId: String) {
        self.clientId = clientId
        Defaults[.clientId] = clientId
        self.apiStatus = .unknown
        self.userInfo = nil
        self.errorMessage = nil
        self.accessToken = nil
    }
    
    private func loadStoredCredentials() {
        self.clientId = Defaults[.clientId]
        self.accessToken = Defaults[.accessToken]
        self.userInfo = Defaults[.userInfo]
        
        if !clientId.isEmpty && accessToken != nil && userInfo != nil {
            self.apiStatus = .valid
        }
    }
    
    private func saveCredentials() {
        Defaults[.clientId] = clientId
        Defaults[.accessToken] = accessToken
        Defaults[.userInfo] = userInfo
        Defaults[.isSetupComplete] = true
        Defaults[.lastLoginDate] = Date()
    }
    
    func clearStoredCredentials() {
        Defaults[.clientId] = ""
        Defaults[.accessToken] = nil
        Defaults[.userInfo] = nil
        Defaults[.isSetupComplete] = false
        Defaults[.lastLoginDate] = nil
        
        self.clientId = ""
        self.accessToken = nil
        self.userInfo = nil
        self.apiStatus = .unknown
        self.errorMessage = nil
    }
    
    var hasStoredCredentials: Bool {
        return !clientId.isEmpty && accessToken != nil && userInfo != nil
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    func startOAuthFlow() {
        guard !clientId.isEmpty else {
            self.apiStatus = .invalid
            self.errorMessage = "Client ID is required"
            return
        }
        
        let state = UUID().uuidString
        let scope = "identity,read,mysubreddits,subreddits"
        
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
        authSession?.prefersEphemeralWebBrowserSession = true
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
            }
            
            await fetchUserInfo()
            
        } catch {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
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
              let url = URL(string: "\(baseURL)/api/v1/me") else {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = "Missing access token"
            }
            return
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
            
            guard httpResponse.statusCode == 200 else {
                await MainActor.run {
                    if httpResponse.statusCode == 401 {
                        self.apiStatus = .invalid
                        self.errorMessage = "Access token expired or invalid"
                    } else {
                        self.apiStatus = .invalid
                        self.errorMessage = "Server error (HTTP \(httpResponse.statusCode))"
                    }
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
            }
            
        } catch {
            await MainActor.run {
                self.apiStatus = .invalid
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func fetchSubscribedSubreddits() async throws -> [Subreddit] {
        guard let accessToken = accessToken,
              let url = URL(string: "\(baseURL)/subreddits/mine.json") else {
            throw APIError.missingAccessToken
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw APIError.invalidToken
                } else if httpResponse.statusCode == 403 {
                    throw APIError.insufficientScope
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("Reddit API Error \(httpResponse.statusCode): \(errorBody)")
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Always log the raw JSON response to debug structure
            if let jsonString = String(data: data, encoding: .utf8) {
                print("=== Reddit API Response ===")
                print(jsonString)
                print("=========================")
            }
            
            do {
                // First, let's try to parse just the basic structure
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let data = json?["data"] as? [String: Any],
                   let children = data["children"] as? [[String: Any]] {
                    print("Found \(children.count) children in response")
                    for (index, child) in children.enumerated() {
                        if let kind = child["kind"] as? String,
                           let childData = child["data"] as? [String: Any] {
                            print("Child \(index): kind=\(kind)")
                            print("Child \(index) keys: \(Array(childData.keys).sorted())")
                        }
                    }
                }
                
                let subredditResponse = try decoder.decode(SubredditResponse.self, from: data)
                return subredditResponse.data.children.map { $0.data }
            } catch {
                print("JSON Decode Error: \(error)")
                throw APIError.parseError
            }
        } catch let urlError as URLError {
            print("Network Error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("Unexpected Error: \(error)")
            throw error
        }
    }
}

enum APIError: LocalizedError {
    case missingAccessToken
    case networkError
    case invalidToken
    case insufficientScope
    case parseError
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Missing access token"
        case .networkError:
            return "Network error - check your connection"
        case .invalidToken:
            return "Access token expired or invalid"
        case .insufficientScope:
            return "Insufficient permissions - please re-authenticate"
        case .parseError:
            return "Failed to parse response data"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        }
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

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}