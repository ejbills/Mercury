import Foundation

/// Service responsible for fetching and managing comments
class CommentsService: BaseRedditService {
    private lazy var avatarManager: AvatarManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarManager(authService: auth)
    }()
    
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

            var usernames = Set<String>()
            let filteredResponses: [CommentResponse] = responses.map { response in
                let filteredChildren: [CommentChild] = response.data.children.compactMap { child in
                    switch child.data {
                    case .comment(let comment):
                        if FilterService.shared.shouldFilterComment(comment) { return nil }
                        collectUsernames(from: comment, into: &usernames)
                        return CommentChild(kind: child.kind, data: .comment(comment))
                    case .more(let more):
                        return CommentChild(kind: child.kind, data: .more(more))
                    }
                }
                let filteredData = CommentListData(children: filteredChildren, after: response.data.after, before: response.data.before)
                return CommentResponse(data: filteredData)
            }

            let avatarMap = await avatarManager.fetchAvatars(for: Array(usernames))

            let enriched: [CommentResponse] = filteredResponses.map { response in
                let newChildren = enrich(children: response.data.children, avatarMap: avatarMap)
                return CommentResponse(data: CommentListData(children: newChildren, after: response.data.after, before: response.data.before))
            }

            return enriched
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
            
            let filteredComments = comments.filter { !FilterService.shared.shouldFilterComment($0) }
            
            let usernames = Set(filteredComments.map { $0.author })
            
            let avatarMap = await avatarManager.fetchAvatars(for: Array(usernames))
            
            let enrichedComments = filteredComments.map { comment in
                var enrichedComment = comment
                if let avatarURL = avatarMap[comment.author] {
                    enrichedComment.authorIconURL = avatarURL
                }
                return enrichedComment
            }
            
            return enrichedComments
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

    func deleteComment(commentId: String) async throws {
        try validateAccessToken()

        guard let url = URL(string: "\(baseURL)/api/del") else {
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

    // MARK: - Submit Comment

    /// Submits a comment or reply.
    /// - Parameters:
    ///   - parentFullname: Fullname of parent (e.g., "t1_<commentId>" or "t3_<postId>").
    ///   - text: Markdown body text.
    /// - Returns: Created `RedditComment` on success.
    func submitComment(parentFullname: String, text: String) async throws -> RedditComment {
        try validateAccessToken()

        guard let url = URL(string: "\(baseURL)/api/comment") else {
            throw APIError.parseError
        }

        var request = createPOSTRequest(url: url)

        let parameters = [
            "api_type": "json",
            "thing_id": parentFullname,
            "text": text
        ]

        let postData = parameters
            .map { key, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(escaped)"
            }
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

            let apiResponse = try decoder.decode(NewCommentAPIResponse.self, from: data)

            if let errors = apiResponse.json.errors, !errors.isEmpty {
                throw APIError.serverError(httpResponse.statusCode)
            }

            guard let thing = apiResponse.json.data.things.first, thing.kind == "t1" else {
                throw APIError.parseError
            }
            return thing.data
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }

    private func collectUsernames(from comment: RedditComment, into usernames: inout Set<String>) {
        usernames.insert(comment.author)
        
        if let replies = comment.replies {
            switch replies {
            case .listing(let commentResponse):
                for child in commentResponse.data.children {
                    if case .comment(let nestedComment) = child.data {
                        if !FilterService.shared.shouldFilterComment(nestedComment) {
                            collectUsernames(from: nestedComment, into: &usernames)
                        }
                    }
                }
            case .empty:
                break
            }
        }
    }
    
    private func enrich(children: [CommentChild], avatarMap: [String: URL]) -> [CommentChild] {
        children.map { child in
            switch child.data {
            case .comment(var c):
                if let url = avatarMap[c.author] {
                    c.authorIconURL = url
                }
                var newReplies = c.replies
                if let replies = c.replies {
                    switch replies {
                    case .listing(let resp):
                        let enrichedChild = enrich(children: resp.data.children, avatarMap: avatarMap)
                        let newData = CommentListData(children: enrichedChild, after: resp.data.after, before: resp.data.before)
                        newReplies = .listing(CommentResponse(data: newData))
                    case .empty:
                        break
                    }
                }
                c.replies = newReplies
                return CommentChild(kind: child.kind, data: .comment(c))
            case .more(let m):
                return CommentChild(kind: child.kind, data: .more(m))
            }
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

// MARK: - Create Comment Response Types

struct NewCommentAPIResponse: Codable {
    let json: NewCommentJSON

    struct NewCommentJSON: Codable {
        let errors: [[String]]?
        let data: NewCommentData
    }

    struct NewCommentData: Codable {
        let things: [NewCommentThing]
    }

    struct NewCommentThing: Codable {
        let kind: String
        let data: RedditComment
    }
}
