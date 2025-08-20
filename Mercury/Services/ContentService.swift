//
//  ContentService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation

/// Service responsible for fetching posts, feeds, and subreddit content
class ContentService: BaseRedditService {
    private lazy var avatarService: AvatarService = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarService(authService: auth)
    }()
    
    // MARK: - Subreddits
    
    func fetchSubscribedSubreddits() async throws -> [Subreddit] {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/subreddits/mine.json") else {
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
            let subredditResponse = try decoder.decode(SubredditResponse.self, from: data)
            return subredditResponse.data.children.map { $0.data }
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // MARK: - Posts and Feeds
    
    func fetchSubredditPosts(subreddit: String, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/r/\(subreddit).json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "r/\(subreddit)")
    }
    
    func fetchHomeFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/.json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "home")
    }
    
    func fetchPopularFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/r/popular.json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "popular")
    }

    // MARK: - Fetch posts by fullnames (e.g., ["t3_abc", "t3_def"]) for comment context
    func fetchPostsByFullnames(_ fullnames: [String]) async throws -> [RedditPost] {
        try validateAccessToken()

        let names = fullnames
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix("t3_") ? $0 : "t3_\($0)" }
            .joined(separator: ",")

        guard !names.isEmpty else { return [] }

        guard let url = URL(string: "\(baseURL)/by_id/\(names).json") else {
            throw APIError.parseError
        }

        let request = createRequest(url: url)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let listing = try decoder.decode(PostResponse.self, from: data)
            return listing.data.children.compactMap { $0.data }
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // MARK: - Voting
    
    func voteOnPost(postId: String, voteDirection: VoteDirection) async throws {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/api/vote") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let fullPostId = postId.hasPrefix("t3_") ? postId : "t3_\(postId)"
        let bodyString = "id=\(fullPostId)&dir=\(voteDirection.rawValue)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch _ as URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // MARK: - Save/Unsave
    
    func savePost(postId: String) async throws {
        try await performSaveAction(postId: postId, save: true)
    }
    
    func unsavePost(postId: String) async throws {
        try await performSaveAction(postId: postId, save: false)
    }
    
    private func performSaveAction(postId: String, save: Bool) async throws {
        try validateAccessToken()
        
        let endpoint = save ? "save" : "unsave"
        guard let url = URL(string: "\(baseURL)/api/\(endpoint)") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let fullPostId = postId.hasPrefix("t3_") ? postId : "t3_\(postId)"
        let bodyString = "id=\(fullPostId)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch _ as URLError {
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
            
            // Custom validation for posts to handle subreddit not found
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.invalidToken
                case 403:
                    throw APIError.insufficientScope
                case 404:
                    if endpoint.contains("r/") {
                        throw APIError.subredditNotFound
                    } else {
                        throw APIError.notFound
                    }
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            let decoder = JSONDecoder()
            
            do {
                let postResponse = try decoder.decode(PostResponse.self, from: data)

                // Filter unwanted posts
                let filteredChildren = postResponse.data.children.compactMap { child -> PostChild? in
                    guard let post = child.data else { return nil }
                    if FilterService.shared.shouldFilterPost(post) { return nil }
                    return PostChild(kind: child.kind, data: post)
                }

                // Batch fetch avatars for authors
                let authorIds = Array(Set(filteredChildren.compactMap { $0.data?.authorFullname }))
                let avatarMap = try await avatarService.fetchUserAvatars(for: authorIds)

                // Enrich posts with avatar URLs
                let enrichedChildren: [PostChild] = filteredChildren.map { child in
                    var post = child.data!
                    if let fid = post.authorFullname, let url = avatarMap[fid] { post.authorIconURL = url }
                    return PostChild(kind: child.kind, data: post)
                }

                let filteredData = PostListData(
                    children: enrichedChildren,
                    after: postResponse.data.after,
                    before: postResponse.data.before,
                    dist: postResponse.data.dist,
                    modhash: postResponse.data.modhash
                )

                return PostResponse(data: filteredData)
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
