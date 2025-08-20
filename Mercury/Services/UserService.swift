//
//  UserService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation

/// Service responsible for user profile operations
class UserService: BaseRedditService {
    private lazy var avatarService: AvatarService = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarService(authService: auth)
    }()
    
    // MARK: - User Profiles
    
    func fetchUserProfile(username: String) async throws -> UserProfile {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/user/\(username)/about.json") else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.invalidToken
                case 404:
                    throw APIError.userNotFound
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
                        
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let userResponse = try decoder.decode(UserProfileResponse.self, from: data)
            return userResponse.data
        } catch _ as DecodingError {
            throw APIError.parseError
        } catch _ as URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    func fetchUserPosts(username: String, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/user/\(username)/submitted.json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "user/\(username)")
    }

    // Fetch a user's recent comments as a flat listing
    func fetchUserComments(username: String, after: String? = nil, limit: Int = 25) async throws -> UserCommentsResponse {
        try validateAccessToken()

        var components = URLComponents(string: "\(baseURL)/user/\(username)/comments.json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.parseError
        }

        let request = createRequest(url: url)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }

            try validateResponse(httpResponse)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let commentsResponse = try decoder.decode(UserCommentsResponse.self, from: data)

            // Filter
            let filteredChildren: [CommentChild] = commentsResponse.data.children.compactMap { child in
                switch child.data {
                case .comment(let comment):
                    return FilterService.shared.shouldFilterComment(comment) ? nil : CommentChild(kind: child.kind, data: .comment(comment))
                case .more:
                    return nil
                }
            }

            // Batch avatars for authors
            let authorIds = Array(Set(filteredChildren.compactMap { child -> String? in
                if case .comment(let c) = child.data { return c.authorFullname } else { return nil }
            }))
            let avatarMap = try await avatarService.fetchUserAvatars(for: authorIds)

            // Enrich comments with avatar URLs
            let enrichedChildren: [CommentChild] = filteredChildren.map { child in
                switch child.data {
                case .comment(var c):
                    if let fid = c.authorFullname, let url = avatarMap[fid] { c.authorIconURL = url }
                    return CommentChild(kind: child.kind, data: .comment(c))
                case .more(let m):
                    return CommentChild(kind: child.kind, data: .more(m))
                }
            }

            let filteredData = CommentListData(
                children: enrichedChildren,
                after: commentsResponse.data.after,
                before: commentsResponse.data.before
            )

            return UserCommentsResponse(data: filteredData)
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func performPostRequest(request: URLRequest, endpoint: String) async throws -> PostResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.invalidToken
                case 403:
                    throw APIError.insufficientScope
                case 404:
                    throw APIError.userNotFound
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            let decoder = JSONDecoder()
            do {
                let postResponse = try decoder.decode(PostResponse.self, from: data)

                // Filter (respect global filters)
                let filteredChildren = postResponse.data.children.compactMap { child -> PostChild? in
                    guard let post = child.data else { return nil }
                    if FilterService.shared.shouldFilterPost(post) { return nil }
                    return PostChild(kind: child.kind, data: post)
                }

                // Batch-fetch avatar URLs
                let authorIds = Array(Set(filteredChildren.compactMap { $0.data?.authorFullname }))
                let avatarMap = try await avatarService.fetchUserAvatars(for: authorIds)

                let enrichedChildren = filteredChildren.map { child in
                    var post = child.data!
                    if let fid = post.authorFullname, let url = avatarMap[fid] { post.authorIconURL = url }
                    return PostChild(kind: child.kind, data: post)
                }

                return PostResponse(data: PostListData(
                    children: enrichedChildren,
                    after: postResponse.data.after,
                    before: postResponse.data.before,
                    dist: postResponse.data.dist,
                    modhash: postResponse.data.modhash
                ))
            } catch {
                throw APIError.parseError
            }
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }

}

// MARK: - User Profile Models

struct UserProfile: Codable, Identifiable {
    let idRaw: String?
    let name: String?
    let linkKarma: Int?
    let commentKarma: Int?
    let created: Double?
    let verified: Bool?
    let hasVerifiedEmail: Bool?
    let iconImg: String?
    let subreddit: ProfileSubreddit?
    let isEmployee: Bool?
    let isMod: Bool?
    let isPremium: Bool?
    let isGold: Bool?
    let hasPaypalSubscription: Bool?
    let hasSubscribedToPremium: Bool?
    let isBlocked: Bool?
    let isFriend: Bool?
    let acceptFollowers: Bool?
    let hideFromRobots: Bool?
    
    enum CodingKeys: String, CodingKey {
        case idRaw = "id"
        case name, verified, subreddit
        case linkKarma = "link_karma"
        case commentKarma = "comment_karma"
        case created = "created_utc"
        case hasVerifiedEmail = "has_verified_email"
        case iconImg = "icon_img"
        case isEmployee = "is_employee"
        case isMod = "is_mod"
        case isPremium = "is_premium"
        case isGold = "is_gold"
        case hasPaypalSubscription = "has_paypal_subscription"
        case hasSubscribedToPremium = "has_subscribed_to_premium"
        case isBlocked = "is_blocked"
        case isFriend = "is_friend"
        case acceptFollowers = "accept_followers"
        case hideFromRobots = "hide_from_robots"
    }
    
    var id: String {
        return idRaw ?? name ?? "unknown"
    }
    
    var actualName: String {
        return name ?? "Unknown User"
    }
    
    var totalKarma: Int {
        let link = linkKarma ?? 0
        let comment = commentKarma ?? 0
        return link + comment
    }
    
    // Use subreddit icon if main iconImg is not available
    var effectiveIconImg: String? {
        if let iconImg = iconImg, !iconImg.isEmpty {
            return iconImg
        }
        return subreddit?.iconImg
    }
    
    var accountAge: String {
        guard let created = created else { return "Unknown" }
        let createdDate = Date(timeIntervalSince1970: created)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdDate)
    }
    
    var profileIconURL: URL? {
        guard let effectiveIcon = effectiveIconImg, !effectiveIcon.isEmpty else { return nil }
        return URL(string: effectiveIcon.replacingOccurrences(of: "&amp;", with: "&"))
    }
}

struct ProfileSubreddit: Codable {
    let displayName: String?
    let title: String?
    let publicDescription: String?
    let subscribers: Int?
    let iconImg: String?
    let bannerImg: String?
    let primaryColor: String?
    let keyColor: String?
    
    enum CodingKeys: String, CodingKey {
        case title, subscribers
        case displayName = "display_name"
        case publicDescription = "public_description"
        case iconImg = "icon_img"
        case bannerImg = "banner_img"
        case primaryColor = "primary_color"
        case keyColor = "key_color"
    }
}

struct UserProfileResponse: Codable {
    let data: UserProfile
}

// Listing response for user comments
struct UserCommentsResponse: Codable {
    let data: CommentListData
}
