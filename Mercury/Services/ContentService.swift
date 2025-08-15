//
//  ContentService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation

/// Service responsible for fetching posts, feeds, and subreddit content
class ContentService: BaseRedditService {
    
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
        } catch let urlError as URLError {
            print(urlError)
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
