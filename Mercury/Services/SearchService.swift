//
//  SearchService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation

/// Service responsible for search functionality
class SearchService: BaseRedditService {
    
    // MARK: - Search Operations
    
    func searchSubreddits(query: String, limit: Int = 25) async throws -> [Subreddit] {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/subreddits/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "type", value: "sr")
        ]
        
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
            let subredditResponse = try decoder.decode(SubredditResponse.self, from: data)
            return subredditResponse.data.children.map { $0.data }
        } catch _ as URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    func searchPosts(query: String, subreddit: String? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        let baseURLString = subreddit != nil ? "\(baseURL)/r/\(subreddit!)/search.json" : "\(baseURL)/search.json"
        var components = URLComponents(string: baseURLString)!
        
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "type", value: "link")
        ]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        if subreddit != nil {
            queryItems.append(URLQueryItem(name: "restrict_sr", value: "true"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "search")
    }
    
    // MARK: - Helper Methods
    
    private func performPostRequest(request: URLRequest, endpoint: String) async throws -> PostResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
            
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
