import Foundation

/// Service responsible for search functionality
class SearchService: BaseRedditService {
    private lazy var avatarManager: AvatarManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarManager(authService: auth)
    }()
    private lazy var subredditIconManager: SubredditIconManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return SubredditIconManager(authService: auth)
    }()

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
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            
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
    
    func searchPosts(
        query: String,
        subreddit: String? = nil,
        after: String? = nil,
        limit: Int = 25,
        sort: String = "relevance",
        timeFrame: String? = nil
    ) async throws -> PostResponse {
        try validateAccessToken()
        
        let baseURLString = subreddit != nil ? "\(baseURL)/r/\(subreddit!)/search.json" : "\(baseURL)/search.json"
        var components = URLComponents(string: baseURLString)!
        
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "type", value: "link")
        ]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        if let timeFrame = timeFrame, !timeFrame.isEmpty {
            queryItems.append(URLQueryItem(name: "t", value: timeFrame))
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
            let (data, response) = try await NetworkManager.shared.session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError
            }

            try validateResponse(httpResponse)

            let decoder = JSONDecoder()

            do {
                let postResponse = try decoder.decode(PostResponse.self, from: data)

                // Enrich posts with avatar and subreddit icons
                let filteredChildren = postResponse.data.children.filter { $0.data != nil }

                let usernames = Array(Set(filteredChildren.compactMap { $0.data?.author }))
                let subreddits = Array(Set(filteredChildren.compactMap { $0.data?.subreddit }))
                async let avatarMapTask = avatarManager.fetchAvatars(for: usernames)
                async let subredditIconMapTask = subredditIconManager.fetchIcons(for: subreddits)
                let (avatarMap, subredditIconMap) = await (avatarMapTask, subredditIconMapTask)

                let enrichedChildren: [PostChild] = filteredChildren.map { child in
                    var post = child.data!
                    if let url = avatarMap[post.author] { post.authorIconURL = url }
                    if let subIcon = subredditIconMap[post.subreddit] { post.subredditIconURL = subIcon }
                    return PostChild(kind: child.kind, data: post)
                }

                let enrichedData = PostListData(
                    children: enrichedChildren,
                    after: postResponse.data.after,
                    before: postResponse.data.before,
                    dist: postResponse.data.dist,
                    modhash: postResponse.data.modhash
                )

                return PostResponse(data: enrichedData)
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
