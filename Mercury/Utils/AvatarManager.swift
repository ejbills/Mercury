import Foundation
import os

class AvatarManager: BaseRedditService {
    private let log = Logger(subsystem: "Mercury", category: "Avatar")

    private var cache: [String: URL] = [:]
    private let cacheLimit = 100
    private let cacheQueue = DispatchQueue(label: "com.mercury.avatar.cache")
    
    override init(authService: AuthenticationService) {
        super.init(authService: authService)
    }
    
    /// Batch fetch avatars and return username -> URL mapping
    func fetchAvatars(for usernames: [String]) async -> [String: URL] {
        let cleanUsernames = usernames.filter { !$0.isEmpty && $0 != "[deleted]" && $0 != "deleted" }
        guard !cleanUsernames.isEmpty else { return [:] }

        var result: [String: URL] = [:]

        for username in cleanUsernames {
            if let cachedURL = cacheQueue.sync(execute: { cache[username] }) {
                result[username] = cachedURL
            }
        }

        let uncachedUsernames = cleanUsernames.filter { username in
            cacheQueue.sync { cache[username] == nil }
        }
        guard !uncachedUsernames.isEmpty else { return result }
        
        await withTaskGroup(of: (String, URL?).self) { group in
            for username in uncachedUsernames {
                group.addTask {
                    do {
                        let url = try await self.fetchSingleAvatar(username: username)
                        return (username, url)
                    } catch {
                        self.log.error("Failed avatar fetch for \(username, privacy: .private): \(String(describing: error), privacy: .public)")
                        return (username, nil)
                    }
                }
            }
            
            for await (username, avatarURL) in group {
                if let url = avatarURL {
                    result[username] = url
                    cacheQueue.sync {
                        cache[username] = url
                        if cache.count > cacheLimit, let key = cache.keys.first {
                            cache.removeValue(forKey: key)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func fetchSingleAvatar(username: String) async throws -> URL? {
        guard let url = URL(string: baseURL + "/user/\(username)/about.json") else {
            log.error("Failed to create about.json URL for \(username, privacy: .private)")
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        
        try validateResponse(http)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let userResponse = try decoder.decode(UserAboutResponse.self, from: data)
            
            let snoovatarImg = userResponse.data.snoovatarImg?.isEmpty == false ? userResponse.data.snoovatarImg : nil
            let profileImg = snoovatarImg ?? userResponse.data.iconImg
            
            if let profileImg = profileImg?.replacingOccurrences(of: "&amp;", with: "&"),
               !profileImg.isEmpty,
               let avatarURL = URL(string: profileImg) {
                return avatarURL
            }
            return nil
        } catch {
            log.error("Decode error for \(username, privacy: .private): \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

// MARK: - Response Models
extension AvatarManager {
    struct UserAboutResponse: Codable {
        let data: UserAboutData
    }
    
    struct UserAboutData: Codable {
        let name: String
        let iconImg: String?
        let snoovatarImg: String?
    }
}
