//
//  RedditPostFetchService.swift
//  Mercury
//
//  Created by AI Assistant on 8/18/25.
//

import Foundation

class RedditPostFetchService {
    static let shared = RedditPostFetchService()
    private let session: URLSession
    private let cache = NSCache<NSString, CachedRedditPost>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        
        // Cache configuration
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    func fetchPost(from url: String) async -> RedditPost? {
        // Check cache first
        let cacheKey = NSString(string: url)
        if let cached = cache.object(forKey: cacheKey) {
            return cached.post
        }
        
        // Extract post info from URL
        guard let postInfo = extractPostInfo(from: url) else {
            return nil
        }
        
        // Construct Reddit JSON API URL
        let apiURL: String
        if let subreddit = postInfo.subreddit, let postId = postInfo.postId {
            // Check if this is a share code (mobile share link) vs regular post ID
            if url.contains("/s/") {
                // For share codes, use the share URL directly but add .json
                apiURL = "https://www.reddit.com/r/\(subreddit)/s/\(postId).json"
            } else {
                // Regular comments URL format
                apiURL = "https://www.reddit.com/r/\(subreddit)/comments/\(postId).json"
            }
        } else if let postId = postInfo.postId {
            // Short URL format - try to get from Reddit's API
            apiURL = "https://www.reddit.com/api/info.json?id=t3_\(postId)"
        } else {
            return nil
        }
        
        return await fetchFromAPI(apiURL: apiURL, originalURL: url)
    }
    
    private func fetchFromAPI(apiURL: String, originalURL: String) async -> RedditPost? {
        guard let url = URL(string: apiURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mercury iOS App", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Handle different response formats
            if apiURL.contains("/api/info.json") {
                // API info response format - reuse existing PostResponse structure
                let infoResponse = try decoder.decode(PostResponse.self, from: data)
                if let post = infoResponse.data.children.first?.data {
                    cachePost(post, for: originalURL)
                    return post
                }
            } else {
                // Comments page response format
                let commentsResponse = try decoder.decode([PostResponse].self, from: data)
                if let postListing = commentsResponse.first,
                   let post = postListing.data.children.first?.data {
                    cachePost(post, for: originalURL)
                    return post
                }
            }
            
            return nil
            
        } catch {
            print("Failed to fetch Reddit post: \(error)")
            return nil
        }
    }
    
    private func extractPostInfo(from url: String) -> (subreddit: String?, postId: String?)? {
        // Handle reddit.com/r/subreddit/comments/postid format
        if url.contains("/r/") && url.contains("/comments/") {
            let components = url.components(separatedBy: "/")
            guard let rIndex = components.firstIndex(of: "r"),
                  rIndex + 1 < components.count,
                  let commentsIndex = components.firstIndex(of: "comments"),
                  commentsIndex + 1 < components.count else {
                return nil
            }
            
            let subreddit = components[rIndex + 1]
            let postId = components[commentsIndex + 1]
            return (subreddit, postId)
        }
        
        // Handle reddit.com/r/subreddit/s/sharecode format (mobile share links)
        if url.contains("/r/") && url.contains("/s/") {
            let components = url.components(separatedBy: "/")
            guard let rIndex = components.firstIndex(of: "r"),
                  rIndex + 1 < components.count,
                  let sIndex = components.firstIndex(of: "s"),
                  sIndex + 1 < components.count else {
                return nil
            }
            
            let subreddit = components[rIndex + 1]
            let shareCode = components[sIndex + 1]
            // For share codes, we'll need to resolve them via Reddit's API
            return (subreddit, shareCode)
        }
        
        // Handle redd.it/postid format
        if url.contains("redd.it/") {
            let postId = url.components(separatedBy: "redd.it/").last
            return (nil, postId)
        }
        
        return nil
    }
    
    private func cachePost(_ post: RedditPost, for url: String) {
        let cacheKey = NSString(string: url)
        let cachedPost = CachedRedditPost(post: post)
        cache.setObject(cachedPost, forKey: cacheKey)
    }
}

// MARK: - Cache Helper
private class CachedRedditPost {
    let post: RedditPost
    
    init(post: RedditPost) {
        self.post = post
    }
}

// MARK: - API Response Models
// Removed custom response structures since we can reuse existing PostResponse from RedditPost.swift

// We'll use the existing RedditPost model directly since it already has proper Codable implementation
// and handles all the Reddit API fields we need

// Removed RedditEdited enum since it already exists in RedditPost.swift as EditedData