//
//  CommentsService.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import Foundation

/// Service responsible for fetching and managing comments
class CommentsService: BaseRedditService {
    
    // MARK: - Comment Fetching
    
    func fetchPostComments(postId: String, sort: CommentSort = .best, limit: Int = 50) async throws -> [CommentResponse] {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/comments/\(postId).json")!
        components.queryItems = [
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
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
            
            // Reddit returns an array where [0] is post, [1] is comments
            let responses = try decoder.decode([CommentResponse].self, from: data)
            
            return responses
        } catch let urlError as URLError {
            print("Comments fetch URL error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("Comments fetch error: \(error)")
            throw error
        }
    }
    
    func fetchMoreComments(postId: String, commentIds: [String], sort: CommentSort = .best) async throws -> [RedditComment] {
        try validateAccessToken()
        
        // Handle empty children arrays - Reddit API doesn't handle this well
        if commentIds.isEmpty {
            print("🔄 CommentsService: Empty children array - returning empty comments")
            return []
        }
        
        guard let url = URL(string: "\(baseURL)/api/morechildren") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let parameters = [
            "api_type": "json",
            "link_id": "t3_\(postId)",
            "children": commentIds.joined(separator: ","),
            "sort": sort.rawValue,
            "limit_children": "true"
        ]
        
        let postData = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.httpBody = postData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // The response structure is different for morechildren
            let jsonResponse = try decoder.decode(MoreChildrenAPIResponse.self, from: data)
            
            // Extract comments from the response
            var comments: [RedditComment] = []
            if let things = jsonResponse.json.data.things {
                print("🔄 CommentsService: API returned \(things.count) things")
                for thing in things {
                    print("🔄 CommentsService: Thing kind: \(thing.kind)")
                    if thing.kind == "t1" {
                        comments.append(thing.data)
                    }
                }
            } else {
                print("🔄 CommentsService: No things in API response")
            }
            
            print("🔄 CommentsService: Extracted \(comments.count) comments from API response")
            return comments
        } catch let urlError as URLError {
            print("More comments fetch URL error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("More comments fetch error: \(error)")
            throw error
        }
    }
    
    // MARK: - Comment Actions
    
    func voteOnComment(commentId: String, voteDirection: VoteDirection) async throws {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/api/vote") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let parameters = [
            "id": "t1_\(commentId)",
            "dir": String(voteDirection.rawValue)
        ]
        
        let postData = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.httpBody = postData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch let urlError as URLError {
            print("Comment vote URL error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("Comment vote error: \(error)")
            throw error
        }
    }
    
    func saveComment(commentId: String) async throws {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/api/save") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let parameters = [
            "id": "t1_\(commentId)"
        ]
        
        let postData = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.httpBody = postData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch let urlError as URLError {
            print("Comment save URL error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("Comment save error: \(error)")
            throw error
        }
    }
    
    func unsaveComment(commentId: String) async throws {
        try validateAccessToken()
        
        guard let url = URL(string: "\(baseURL)/api/unsave") else {
            throw APIError.parseError
        }
        
        var request = createPOSTRequest(url: url)
        
        let parameters = [
            "id": "t1_\(commentId)"
        ]
        
        let postData = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.httpBody = postData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch let urlError as URLError {
            print("Comment unsave URL error: \(urlError)")
            throw APIError.networkError
        } catch {
            print("Comment unsave error: \(error)")
            throw error
        }
    }
}

// MARK: - Supporting Types

struct MoreCommentsResponse: Codable {
    let json: MoreCommentsData
    
    struct MoreCommentsData: Codable {
        let data: CommentResponse
    }
}

struct MoreChildrenAPIResponse: Codable {
    let json: MoreChildrenData
    
    struct MoreChildrenData: Codable {
        let data: MoreChildrenContent
    }
    
    struct MoreChildrenContent: Codable {
        let things: [CommentThing]?
    }
    
    struct CommentThing: Codable {
        let kind: String
        let data: RedditComment
    }
}
