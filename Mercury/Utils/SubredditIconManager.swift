import Foundation
import os

class SubredditIconManager: BaseRedditService {
    private let log = Logger(subsystem: "Mercury", category: "SubredditIcon")

    private var cache: [String: URL] = [:]
    private let cacheLimit = 200
    private let cacheQueue = DispatchQueue(label: "com.mercury.subreddit.icon.cache")

    /// Batch fetch subreddit icons and return subredditName -> URL mapping
    func fetchIcons(for subreddits: [String]) async -> [String: URL] {
        let clean = subreddits
            .map { $0.hasPrefix("r/") ? String($0.dropFirst(2)) : $0 }
            .filter { !$0.isEmpty }

        guard !clean.isEmpty else { return [:] }

        var result: [String: URL] = [:]

        // Use cache first
        for name in clean {
            if let url = cacheQueue.sync(execute: { cache[name.lowercased()] }) {
                result[name] = url
            }
        }

        let toFetch = clean.filter { name in
            cacheQueue.sync { cache[name.lowercased()] == nil }
        }
        guard !toFetch.isEmpty else { return result }

        await withTaskGroup(of: (String, URL?).self) { group in
            for name in toFetch {
                group.addTask { [weak self] in
                    guard let self else { return (name, nil) }
                    do {
                        let icon = try await self.fetchSingle(name: name)
                        return (name, icon)
                    } catch {
                        self.log.debug("Failed to fetch icon for r/\(name, privacy: .private): \(String(describing: error), privacy: .public)")
                        return (name, nil)
                    }
                }
            }

            for await (name, url) in group {
                if let url {
                    result[name] = url
                    cacheQueue.sync {
                        cache[name.lowercased()] = url
                        if cache.count > cacheLimit, let key = cache.keys.first {
                            cache.removeValue(forKey: key)
                        }
                    }
                }
            }
        }

        return result
    }

    private func fetchSingle(name: String) async throws -> URL? {
        guard let url = URL(string: baseURL + "/r/\(name)/about.json") else {
            throw APIError.parseError
        }
        let request = createRequest(url: url)
        let (data, response) = try await NetworkManager.shared.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        try validateResponse(http)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        struct Wrapper: Codable { let data: Subreddit }
        let about = try decoder.decode(Wrapper.self, from: data).data
        return about.iconURL
    }
}

