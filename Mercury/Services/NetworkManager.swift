import Foundation
import Defaults
import CFNetwork

/// Centralized URLSession manager that applies proxy settings across the app
/// ALL network requests MUST use NetworkManager.shared.session to ensure proxy compliance
final class NetworkManager: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let shared = NetworkManager()

    private(set) var session: URLSession!
    

    // Cache latest credentials for proxy auth challenges
    private var proxyUsername: String? { Defaults[.proxyUsername] }
    private var proxyPassword: String? { Defaults[.proxyPassword] }

    override private init() {
        super.init()
        rebuildSession()
    }

    /// Rebuilds the shared session reflecting current Defaults proxy settings
    func rebuildSession() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

        if Defaults[.proxyEnabled], let dict = Self.makeProxyDictionary() {
            config.connectionProxyDictionary = dict
        } else {
            config.connectionProxyDictionary = nil
        }

        // Use an operation queue with limited concurrency if desired
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 6

        self.session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }

    /// Helper to refresh the session after settings change
    func applyCurrentSettings() {
        rebuildSession()
    }

    /// Build CFNetwork proxy dictionary from Defaults
    private static func makeProxyDictionary() -> [AnyHashable: Any]? {
        guard let host = Defaults[.proxyHost], !host.isEmpty,
              let port = Defaults[.proxyPort], port > 0 else {
            return nil
        }

        var dict: [AnyHashable: Any] = [:]

        switch Defaults[.proxyType] {
        case .http:
            dict["HTTPEnable"] = 1
            dict["HTTPProxy"] = host
            dict["HTTPPort"] = port
            // Also mirror to HTTPS to cover TLS endpoints
            dict["HTTPSEnable"] = 1
            dict["HTTPSProxy"] = host
            dict["HTTPSPort"] = port
            // Add HTTP authentication if credentials are provided
            if let user = Defaults[.proxyUsername], !user.isEmpty,
               let pass = Defaults[.proxyPassword], !pass.isEmpty {
                dict["HTTPUser"] = user
                dict["HTTPPassword"] = pass
                dict["HTTPSUser"] = user
                dict["HTTPSPassword"] = pass
            }
        case .https:
            dict["HTTPSEnable"] = 1
            dict["HTTPSProxy"] = host
            dict["HTTPSPort"] = port
            // Add HTTPS authentication if credentials are provided
            if let user = Defaults[.proxyUsername], !user.isEmpty,
               let pass = Defaults[.proxyPassword], !pass.isEmpty {
                dict["HTTPSUser"] = user
                dict["HTTPSPassword"] = pass
            }
        case .socks5:
            dict["SOCKSEnable"] = 1
            dict["SOCKSProxy"] = host
            dict["SOCKSPort"] = port
            // Add SOCKS authentication if credentials are provided
            if let user = Defaults[.proxyUsername], !user.isEmpty,
               let pass = Defaults[.proxyPassword], !pass.isEmpty {
                dict["SOCKSUser"] = user
                dict["SOCKSPassword"] = pass
            }
        }

        return dict
    }

    // MARK: - URLSessionDelegate (Proxy authentication support)

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle proxy auth if username/password are set
        if let user = proxyUsername, !user.isEmpty, let pass = proxyPassword, !pass.isEmpty {
            let credential = URLCredential(user: user, password: pass, persistence: .forSession)
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - Test Connection
    
    func testConnection() async -> (success: Bool, message: String, ipAddress: String?) {
        let testURL = URL(string: "https://api.ipify.org?format=json")!
        
        do {
            let (data, response) = try await session.data(from: testURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check if response is successful
                guard httpResponse.statusCode == 200 else {
                    let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    return (false, "HTTP \(httpResponse.statusCode): \(responseText)", nil)
                }
            }
            
            // Try to parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ip = json["ip"] as? String {
                    return (true, "Connection successful", ip)
                }
            } catch {
                // If JSON parsing fails, try as plain text
                if let ipString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return (true, "Connection successful", ipString)
                }
            }
            
            return (false, "Invalid response format", nil)
            
        } catch {
            return (false, "Connection failed: \(error.localizedDescription)", nil)
        }
    }
}
