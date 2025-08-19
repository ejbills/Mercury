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
    
    func fetchPostComments(postId: String, sort: CommentSort = .best, limit: Int = 50, after: String? = nil, focusCommentId: String? = nil, context: Int? = nil) async throws -> [CommentResponse] {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/comments/\(postId).json")!
        var queryItems = [
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        if let focus = focusCommentId { queryItems.append(URLQueryItem(name: "comment", value: focus)) }
        if let ctx = context { queryItems.append(URLQueryItem(name: "context", value: String(ctx))) }
        
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
            
            let responses = try decoder.decode([CommentResponse].self, from: data)
            
            let filteredResponses = responses.map { response in
                let filteredChildren = response.data.children.filter { child in
                    guard child.kind == "t1" else { return true }
                    if case .comment(let comment) = child.data {
                        return !FilterService.shared.shouldFilterComment(comment)
                    }
                    return true
                }
                
                let filteredData = CommentListData(
                    children: filteredChildren,
                    after: response.data.after,
                    before: response.data.before
                )
                
                return CommentResponse(data: filteredData)
            }
            
            return filteredResponses
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    func fetchMoreComments(postId: String, commentIds: [String], sort: CommentSort = .best) async throws -> [RedditComment] {
        try validateAccessToken()
        
        if commentIds.isEmpty {
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
            
            let jsonResponse = try decoder.decode(MoreChildrenAPIResponse.self, from: data)
            
            var comments: [RedditComment] = []
            if let things = jsonResponse.json.data.things {
                for thing in things where thing.kind == "t1" {
                    comments.append(thing.data)
                }
            }
            return comments.filter { !FilterService.shared.shouldFilterComment($0) }
        } catch is URLError {
            throw APIError.networkError
        } catch {
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
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch is URLError {
            throw APIError.networkError
        } catch {
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
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch is URLError {
            throw APIError.networkError
        } catch {
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
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }
            
            try validateResponse(httpResponse)
        } catch is URLError {
            throw APIError.networkError
        } catch {
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
