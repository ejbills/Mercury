//
//  UserService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation

/// Service responsible for user profile operations
class UserService: BaseRedditService {
    
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
        } catch let decodingError as DecodingError {
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
            // Note: We use explicit CodingKeys mappings instead of .convertFromSnakeCase
            // to avoid conflicts with field decoding
            
            do {
                let postResponse = try decoder.decode(PostResponse.self, from: data)
                return postResponse
            } catch {
                throw APIError.parseError
            }
        } catch let urlError as URLError {
            print(urlError)
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
