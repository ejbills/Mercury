import Foundation

/// Service responsible for fetching posts, feeds, and subreddit content
class ContentService: BaseRedditService {
    private lazy var avatarManager: AvatarManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarManager(authService: auth)
    }()
    
    // MARK: - Subreddits

    func fetchSubscribedSubreddits() async throws -> [Subreddit] {
        try validateAccessToken()
        
        var allSubreddits: [Subreddit] = []
        var after: String? = nil
        let limit = 100 // Maximum allowed by Reddit API
        
        repeat {
            var components = URLComponents(string: "\(baseURL)/subreddits/mine.json")!
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
                let (data, response) = try await NetworkManager.shared.session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError
                }
                
                try validateResponse(httpResponse)
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let subredditResponse = try decoder.decode(SubredditResponse.self, from: data)
                
                let pageSubreddits = subredditResponse.data.children.map { $0.data }
                allSubreddits.append(contentsOf: pageSubreddits)
                after = subredditResponse.data.after
                
                // If we got fewer than the limit, we've reached the end
                if pageSubreddits.count < limit {
                    break
                }
                
            } catch is URLError {
                throw APIError.networkError
            } catch {
                throw error
            }
        } while after != nil
        
        return allSubreddits
    }

    /// Subscribe to a subreddit
    func subscribe(to subreddit: String) async throws {
        try await performSubscribeAction(subreddit: subreddit, subscribe: true)
    }

    /// Unsubscribe from a subreddit
    func unsubscribe(from subreddit: String) async throws {
        try await performSubscribeAction(subreddit: subreddit, subscribe: false)
    }

    /// Fetch subreddit about info (for sidebar)
    func fetchSubredditAbout(subreddit: String) async throws -> Subreddit {
        try validateAccessToken()

        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        guard let url = URL(string: "\(baseURL)/r/\(clean)/about.json") else {
            throw APIError.parseError
        }

        let request = createRequest(url: url)

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            struct AboutWrapper: Codable { let data: Subreddit }
            let about = try decoder.decode(AboutWrapper.self, from: data)
            return about.data
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }

    // MARK: - Private helpers (Subreddits)

    private func performSubscribeAction(subreddit: String, subscribe: Bool) async throws {
        try validateAccessToken()

        guard let url = URL(string: "\(baseURL)/api/subscribe") else {
            throw APIError.parseError
        }

        var request = createPOSTRequest(url: url)
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        let action = subscribe ? "sub" : "unsub"
        let body = "action=\(action)&sr_name=\(clean)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (_, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // MARK: - Posts and Feeds
    
    func fetchSubredditPosts(subreddit: String, sort: PostSort = .hot, timeFrame: TopTimeFrame? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/r/\(subreddit)/\(sort.rawValue).json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        if let timeFrame = timeFrame, sort.supportsTimeFrame {
            queryItems.append(URLQueryItem(name: "t", value: timeFrame.rawValue))
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
    
    func fetchSavedPosts(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/user/\(authService?.userInfo?.name ?? "")/saved.json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "saved")
    }

    // MARK: - Fetch posts by fullnames (e.g., ["t3_abc", "t3_def"]) for comment context
    func fetchPostsByFullnames(_ fullnames: [String]) async throws -> [RedditPost] {
        try validateAccessToken()

        let names = fullnames
            .filter { !$0.isEmpty }
            .map { Fullname.post($0) }
            .joined(separator: ",")

        guard !names.isEmpty else { return [] }

        guard let url = URL(string: "\(baseURL)/by_id/\(names).json") else {
            throw APIError.parseError
        }

        let request = createRequest(url: url)

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
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
        
        let fullPostId = Fullname.post(postId)
        let bodyString = "id=\(fullPostId)&dir=\(voteDirection.rawValue)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (_, response) = try await NetworkManager.shared.session.data(for: request)
            
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
        
        let fullPostId = Fullname.post(postId)
        let bodyString = "id=\(fullPostId)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (_, response) = try await NetworkManager.shared.session.data(for: request)
            
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

    // MARK: - Hide/Unhide Posts

    func hidePost(postId: String) async throws {
        try await performHideAction(postId: postId, hide: true)
    }

    func unhidePost(postId: String) async throws {
        try await performHideAction(postId: postId, hide: false)
    }

    private func performHideAction(postId: String, hide: Bool) async throws {
        try validateAccessToken()

        let endpoint = hide ? "hide" : "unhide"
        guard let url = URL(string: "\(baseURL)/api/\(endpoint)") else {
            throw APIError.parseError
        }

        var request = createPOSTRequest(url: url)

        let fullPostId = Fullname.post(postId)
        let bodyString = "id=\(fullPostId)"
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (_, response) = try await NetworkManager.shared.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.networkError }
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
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            
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

                let filteredChildren = postResponse.data.children.compactMap { child -> PostChild? in
                    guard let post = child.data else { return nil }
                    if FilterService.shared.shouldFilterPost(post) { return nil }
                    return PostChild(kind: child.kind, data: post)
                }

                let usernames = Array(Set(filteredChildren.compactMap { $0.data?.author }))
                let avatarMap = await avatarManager.fetchAvatars(for: usernames)

                let enrichedChildren: [PostChild] = filteredChildren.map { child in
                    var post = child.data!
                    if let url = avatarMap[post.author] { post.authorIconURL = url }
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
