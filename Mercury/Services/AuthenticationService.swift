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
    // Multi-account
    var storedAccounts: [StoredAccount] = []
    var activeUsername: String? = nil
    
    private var clientId: String = ""
    private let redirectURI = "mercury://oauth"
    private var authSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshTimer: Timer?
    private var isRefreshingToken = false
    private var refreshRetryCount = 0
    private let maxRefreshRetries = 3
    private var refreshWaiters: [CheckedContinuation<Bool, Never>] = []
    // Pending values for seamless add/switch flows
    private var pendingClientId: String? = nil
    private var pendingRefreshToken: String? = nil
    private let tokenOverrideLock = NSLock()
    private var requestTokenOverride: TokenOverride?
    
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
        self.storedAccounts = Defaults[.storedAccounts]
        self.activeUsername = Defaults[.activeUsername]
        
        if !clientId.isEmpty && accessToken != nil && userInfo != nil {
            self.apiStatus = .valid
            if isAccessTokenExpired(threshold: 0), refreshToken != nil {
                Task { _ = await self.refreshAccessToken() }
            } else {
                scheduleTokenRefreshIfNeeded()
            }
        }
    }
    
    private func saveCredentials(shouldUpsertAccount: Bool = true) {
        Defaults[.clientId] = clientId
        Defaults[.accessToken] = accessToken
        Defaults[.refreshToken] = refreshToken
        Defaults[.accessTokenExpiry] = accessTokenExpiry
        Defaults[.userInfo] = userInfo
        Defaults[.isSetupComplete] = true
        Defaults[.lastLoginDate] = Date()

        // Persist multi-account info if available
        if shouldUpsertAccount, let user = userInfo, let rt = refreshToken {
            upsertStoredAccount(username: user.name, refreshToken: rt)
            Defaults[.storedAccounts] = storedAccounts
            Defaults[.activeUsername] = user.name
            activeUsername = user.name
        }
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
        self.refreshRetryCount = 0
        self.isRefreshingToken = false
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    var hasStoredCredentials: Bool {
        return !clientId.isEmpty && accessToken != nil && userInfo != nil
    }

    func currentRequestAccessToken() -> String? {
        tokenOverrideLock.lock()
        let override = requestTokenOverride
        tokenOverrideLock.unlock()
        if let override {
            return override.accessToken
        }
        return accessToken
    }

    func hasAccessTokenForRequests() -> Bool {
        tokenOverrideLock.lock()
        let overrideHasToken = requestTokenOverride?.accessToken.isEmpty == false
        tokenOverrideLock.unlock()
        return overrideHasToken || accessToken != nil
    }

    private func swapTokenOverride(_ newValue: TokenOverride?) -> TokenOverride? {
        tokenOverrideLock.lock()
        let previous = requestTokenOverride
        requestTokenOverride = newValue
        tokenOverrideLock.unlock()
        return previous
    }
    
    // MARK: - OAuth Flow
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Prefer an existing window from a foreground UIWindowScene
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) { return key }
            if let any = scene.windows.first { return any }
            // Create a transient, scene-attached window as anchor
            return UIWindow(windowScene: scene)
        }
        // Fallback to any available scene
        if let scene = scenes.first {
            if let any = scene.windows.first { return any }
            return UIWindow(windowScene: scene)
        }
        preconditionFailure("No UIWindowScene available for ASWebAuthenticationSession presentation anchor")
    }
    
    func startOAuthFlow(clientId override: String? = nil) {
        if let override, !override.isEmpty { pendingClientId = override }
        let useClientId = pendingClientId ?? clientId
        guard !useClientId.isEmpty else {
            self.apiStatus = .invalid
            self.errorMessage = "Client ID is required"
            return
        }
        
        
        
        let state = UUID().uuidString
        let scope = "identity,edit,flair,history,modconfig,modflair,modlog,modposts,modwiki,mysubreddits,privatemessages,read,report,save,submit,subscribe,vote,wikiedit,wikiread"
        
        var components = URLComponents(string: "https://www.reddit.com/api/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: useClientId),
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
        
        let useClientId = pendingClientId ?? clientId
        let credentials = "\(useClientId):".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyData = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)".data(using: .utf8)
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            
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
                if let rt = tokenResponse.refreshToken {
                    self.refreshToken = rt
                }
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

        if isAccessTokenExpired(), let _ = refreshToken {
            _ = await refreshAccessToken()
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.apiStatus = .networkError
                    self.errorMessage = "Network error"
                }
                return
            }
            
            if httpResponse.statusCode == 401 {
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
                if let p = self.pendingClientId {
                    self.clientId = p
                    Defaults[.clientId] = p
                    self.pendingClientId = nil
                }
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
            Task {
                let success = await self?.refreshAccessToken() ?? false
                if !success {
                    await self?.handleRefreshFailure(isScheduled: true)
                }
            }
        }
    }
    
    @discardableResult
    func refreshAccessToken() async -> Bool {
        let useClientId = pendingClientId ?? clientId
        let useRefreshToken = pendingRefreshToken ?? refreshToken

        let shouldWaitForInFlight = await MainActor.run { () -> Bool in
            if self.isRefreshingToken {
                return true
            } else {
                self.isRefreshingToken = true
                return false
            }
        }

        if shouldWaitForInFlight {
            return await withCheckedContinuation { continuation in
                Task { @MainActor in
                    self.refreshWaiters.append(continuation)
                }
            }
        }

        guard let refreshToken = useRefreshToken, !useClientId.isEmpty else {
            return await finishRefresh(success: false)
        }
        guard let url = URL(string: "https://www.reddit.com/api/v1/access_token") else {
            return await finishRefresh(success: false)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = "\(useClientId):".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await handleRefreshError("Network error during token refresh")
                return await finishRefresh(success: false)
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMsg = "Token refresh failed with status \(httpResponse.statusCode)"
                await handleRefreshError(errorMsg)
                return await finishRefresh(success: false)
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            // Validate token response
            guard !tokenResponse.accessToken.isEmpty,
                  let expiresIn = tokenResponse.expiresIn,
                  expiresIn > 0 else {
                await handleRefreshError("Invalid token response from server")
                return await finishRefresh(success: false)
            }
            
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken

                // Check if we're in an account switch scenario
                let isSwitching = self.pendingRefreshToken != nil || self.pendingClientId != nil

                // Apply pending tokens first (account switch scenario)
                if let p = self.pendingClientId {
                    self.clientId = p
                    Defaults[.clientId] = p
                }

                if let pr = self.pendingRefreshToken {
                    self.refreshToken = pr
                    Defaults[.refreshToken] = pr
                }

                // Then apply new refresh token from response if provided
                if let newRT = tokenResponse.refreshToken {
                    self.refreshToken = newRT
                    Defaults[.refreshToken] = newRT
                }

                self.accessTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                self.pendingClientId = nil
                self.pendingRefreshToken = nil
                self.refreshRetryCount = 0 // Reset retry count on success
                self.apiStatus = .valid
                self.errorMessage = nil

                // Don't upsert account during switch - wait until fetchUserInfo completes
                self.saveCredentials(shouldUpsertAccount: !isSwitching)
                self.scheduleTokenRefreshIfNeeded()
            }
            return await finishRefresh(success: true)
            
        } catch {
            await handleRefreshError("Token refresh error: \(error.localizedDescription)")
            return await finishRefresh(success: false)
        }
    }

    private func finishRefresh(success: Bool) async -> Bool {
        let waiters = await MainActor.run { () -> [CheckedContinuation<Bool, Never>] in
            self.isRefreshingToken = false
            let pending = self.refreshWaiters
            self.refreshWaiters.removeAll()
            return pending
        }
        
        for waiter in waiters {
            waiter.resume(returning: success)
        }
        
        return success
    }
    
    // MARK: - Error Handling
    
    private func handleRefreshError(_ message: String) async {
        await MainActor.run {
            self.refreshRetryCount += 1
            self.errorMessage = message
            
            if self.refreshRetryCount >= self.maxRefreshRetries {
                // Max retries reached - mark as invalid and require re-authentication
                self.apiStatus = .invalid
                self.refreshRetryCount = 0
            } else {
                // Schedule a retry with exponential backoff
                self.scheduleRefreshRetry()
            }
        }
    }
    
    private func handleRefreshFailure(isScheduled: Bool) async {
        await MainActor.run {
            if isScheduled {
                // Scheduled refresh failed - try manual refresh with retry logic
                Task {
                    let success = await self.refreshAccessToken()
                    if !success {
                        await self.handleRefreshError("Scheduled token refresh failed")
                    }
                }
            } else {
                self.apiStatus = .invalid
                self.errorMessage = "Token refresh failed - please re-authenticate"
            }
        }
    }
    
    private func scheduleRefreshRetry() {
        tokenRefreshTimer?.invalidate()
        
        // Exponential backoff: 5s, 15s, 45s
        let baseDelay: TimeInterval = 5
        let retryDelay = baseDelay * pow(3.0, Double(refreshRetryCount - 1))
        
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            Task {
                let success = await self?.refreshAccessToken() ?? false
                if !success {
                    await self?.handleRefreshError("Token refresh retry failed")
                }
            }
        }
    }

    // Public helper for building an authorization URL for display/copy
    func buildAuthorizationURL(for clientId: String) -> URL? {
        let scope = "identity,edit,flair,history,modconfig,modflair,modlog,modposts,modwiki,mysubreddits,privatemessages,read,report,save,submit,subscribe,vote,wikiedit,wikiread"
        var components = URLComponents(string: "https://www.reddit.com/api/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "duration", value: "permanent"),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components.url
    }

    // MARK: - Multi-account helpers
    private func upsertStoredAccount(username: String, refreshToken: String) {
        if let idx = storedAccounts.firstIndex(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) {
            storedAccounts[idx].refreshToken = refreshToken
            storedAccounts[idx].lastUpdated = Date()
            storedAccounts[idx].clientId = self.clientId
        } else {
            storedAccounts.append(StoredAccount(username: username, refreshToken: refreshToken, lastUpdated: Date(), clientId: self.clientId))
        }
        Defaults[.storedAccounts] = storedAccounts
    }

    func switchToAccount(username: String) async {
        guard let acct = storedAccounts.first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) else {
            return
        }

        var didChangeAccount = false
        await MainActor.run {
            let previousUsername = self.activeUsername
            // Stage pending values and mark active account; do not clear current session
            self.pendingRefreshToken = acct.refreshToken
            self.pendingClientId = acct.clientId ?? self.clientId
            self.activeUsername = acct.username
            Defaults[.activeUsername] = acct.username
            didChangeAccount = previousUsername?.caseInsensitiveCompare(acct.username) != .orderedSame
        }

        let refreshed = await refreshAccessToken()

        if refreshed {
            await fetchUserInfo()
            if didChangeAccount {
                await MainActor.run {
                    NotificationCenter.default.post(name: .mercuryAccountDidSwitch, object: self.activeUsername)
                }
            }
        }
    }

    func removeAccount(username: String) {
        storedAccounts.removeAll { $0.username.caseInsensitiveCompare(username) == .orderedSame }
        Defaults[.storedAccounts] = storedAccounts
        // If removing current account
        if activeUsername?.caseInsensitiveCompare(username) == .orderedSame {
            if let next = storedAccounts.first {
                Task { await switchToAccount(username: next.username) }
            } else {
                // No accounts left: clear session but keep app config (clientId)
                clearActiveSessionPreservingAppConfig()
                Defaults[.activeUsername] = nil
                activeUsername = nil
                Task { @MainActor in
                    NotificationCenter.default.post(name: .mercuryAccountDidSwitch, object: nil)
                }
            }
        }
    }

    // Clear tokens/user info while preserving clientId and setup state
    private func clearActiveSessionPreservingAppConfig() {
        Defaults[.accessToken] = nil
        Defaults[.refreshToken] = nil
        Defaults[.accessTokenExpiry] = nil
        Defaults[.userInfo] = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.accessTokenExpiry = nil
        self.userInfo = nil
        self.apiStatus = .unknown
        self.errorMessage = nil
        self.refreshRetryCount = 0
        self.isRefreshingToken = false
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }

    func performUsingAccount<T>(username: String, body: @escaping () async throws -> T) async throws -> T {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await body()
        }

        let isActiveAccount = await MainActor.run { () -> Bool in
            if let active = self.userInfo?.name ?? self.activeUsername {
                return active.caseInsensitiveCompare(trimmed) == .orderedSame
            }
            return false
        }

        if isActiveAccount {
            return try await body()
        }

        let stored = await MainActor.run {
            self.storedAccounts.first { $0.username.caseInsensitiveCompare(trimmed) == .orderedSame }
        }

        guard let stored else {
            throw AccountImpersonationError.accountNotFound
        }

        let clientIdToUse = await MainActor.run {
            stored.clientId ?? self.clientId
        }
        guard !clientIdToUse.isEmpty else {
            throw AccountImpersonationError.missingClientId
        }

        let tokenResponse = try await requestAccessToken(clientId: clientIdToUse, refreshToken: stored.refreshToken)

        if let newRT = tokenResponse.refreshToken, newRT != stored.refreshToken {
            await MainActor.run {
                self.updateStoredAccount(username: stored.username, refreshToken: newRT, clientId: clientIdToUse)
            }
        } else {
            await MainActor.run {
                self.updateStoredAccount(username: stored.username, refreshToken: nil, clientId: clientIdToUse)
            }
        }

        let override = TokenOverride(
            username: stored.username,
            accessToken: tokenResponse.accessToken,
            expiry: tokenResponse.expiresIn.flatMap { Date().addingTimeInterval(TimeInterval($0)) }
        )

        let previousOverride = swapTokenOverride(override)
        defer { _ = swapTokenOverride(previousOverride) }

        return try await body()
    }

    private func requestAccessToken(clientId: String, refreshToken: String) async throws -> TokenResponse {
        guard let url = URL(string: "https://www.reddit.com/api/v1/access_token") else {
            throw AccountImpersonationError.tokenExchangeFailed("Invalid token endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = "\(clientId):".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AccountImpersonationError.tokenExchangeFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let description = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw AccountImpersonationError.tokenExchangeFailed(description)
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            guard !tokenResponse.accessToken.isEmpty else {
                throw AccountImpersonationError.tokenExchangeFailed("Empty access token")
            }

            return tokenResponse
        } catch let error as AccountImpersonationError {
            throw error
        } catch {
            throw AccountImpersonationError.tokenExchangeFailed(error.localizedDescription)
        }
    }

    @MainActor
    private func updateStoredAccount(username: String, refreshToken: String?, clientId: String?) {
        guard let idx = storedAccounts.firstIndex(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) else { return }
        if let refreshToken {
            storedAccounts[idx].refreshToken = refreshToken
        }
        if let clientId {
            storedAccounts[idx].clientId = clientId
        }
        storedAccounts[idx].lastUpdated = Date()
        Defaults[.storedAccounts] = storedAccounts
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

extension Notification.Name {
    static let mercuryAccountDidSwitch = Notification.Name("MercuryAccountDidSwitch")
}

private struct TokenOverride {
    let username: String
    let accessToken: String
    let expiry: Date?
}

enum AccountImpersonationError: LocalizedError {
    case accountNotFound
    case missingClientId
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Selected account could not be found."
        case .missingClientId:
            return "Missing client ID for the selected account."
        case .tokenExchangeFailed(let message):
            return "Couldn't authenticate selected account: \(message)"
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
