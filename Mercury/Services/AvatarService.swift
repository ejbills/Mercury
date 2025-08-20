//
//  AvatarService.swift
//  Mercury
//
//  Centralized service for batching user avatar lookups.
//

import Foundation

class AvatarService: BaseRedditService {
    struct AccountUserData: Codable {
        let iconImg: String?
        let snoovatarImg: String?
    }

    /// Returns a map of account fullname (e.g., t2_xxx) -> avatar URL
    func fetchUserAvatars(for accountIds: [String]) async throws -> [String: URL] {
        let ids = Array(Set(accountIds.filter { !$0.isEmpty }))
        guard !ids.isEmpty else { return [:] }

        var components = URLComponents(string: baseURL + "/api/user_data_by_account_ids.json")!
        components.queryItems = [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]
        guard let url = components.url else { throw APIError.parseError }

        let request = createRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        try validateResponse(http)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let map = try decoder.decode([String: AccountUserData].self, from: data)
            var result: [String: URL] = [:]
            for (k, v) in map {
                if let urlStr = (v.snoovatarImg.nilIfEmpty ?? v.iconImg.nilIfEmpty)?.replacingOccurrences(of: "&amp;", with: "&"),
                   let url = URL(string: urlStr) {
                    result[k] = url
                }
            }
            return result
        } catch {
            throw APIError.parseError
        }
    }
}

