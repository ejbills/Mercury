import Foundation
import UIKit

/// Service responsible for fetching posts, feeds, and subreddit content
class ContentService: BaseRedditService {
    private lazy var avatarManager: AvatarManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return AvatarManager(authService: auth)
    }()
    private lazy var subredditIconManager: SubredditIconManager = {
        guard let auth = self.authService else { fatalError("Missing authService") }
        return SubredditIconManager(authService: auth)
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

    // MARK: - Multireddits

    /// Fetch the current user's multireddits
    func fetchUserMultireddits() async throws -> [MultiReddit] {
        try validateAccessToken()

        guard let url = URL(string: "\(baseURL)/api/multi/mine.json") else {
            throw APIError.parseError
        }
        let request = createRequest(url: url)

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            // API returns an array of labeled multi objects
            let labeled = try decoder.decode([LabeledMulti].self, from: data)
            let result: [MultiReddit] = labeled.map { lm in
                MultiReddit(
                    name: lm.data.name,
                    path: lm.data.path,
                    descriptionMd: lm.data.descriptionMd,
                    iconUrl: lm.data.iconUrl,
                    subreddits: lm.data.subreddits.map { $0.name }
                )
            }
            return result
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }

    /// Fetch posts for a multireddit under a given user
    func fetchMultiPosts(username: String, multi: String, sort: PostSort = .hot, timeFrame: TopTimeFrame? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()

        var components = URLComponents(string: "\(baseURL)/user/\(username)/m/\(multi)/\(sort.rawValue).json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let after = after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let timeFrame = timeFrame, sort.supportsTimeFrame { queryItems.append(URLQueryItem(name: "t", value: timeFrame.rawValue)) }
        queryItems.append(URLQueryItem(name: "cache_buster", value: cacheBusterValue()))
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.parseError }
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "user/\(username)/m/\(multi)")
    }

    // MARK: - Create / Edit / Delete Multireddits

    /// Create a new multireddit for the current user
    func createMultireddit(displayName: String, subreddits: [String], descriptionMd: String? = nil, iconName: String? = nil, keyColor: String? = nil, visibility: String? = nil) async throws -> MultiReddit {
        try validateAccessToken()
        guard let username = authService?.userInfo?.name else { throw APIError.userNotFound }
        guard let url = URL(string: "\(baseURL)/api/multi") else { throw APIError.parseError }

        var request = createPOSTRequest(url: url)
        // Build JSON model per Reddit API
        let model: [String: Any] = {
            var m: [String: Any] = [
                "display_name": displayName,
                "subreddits": subreddits.map { ["name": $0] }
            ]
            if let descriptionMd { m["description_md"] = descriptionMd }
            if let iconName { m["icon_name"] = iconName }
            if let keyColor { m["key_color"] = keyColor }
            if let visibility { m["visibility"] = visibility }
            return m
        }()

        let multipath = "/user/\(username)/m/\(displayName)"
        let jsonData = try JSONSerialization.data(withJSONObject: model, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let body = "multipath=\(multipath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? multipath)&model=\(jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jsonString)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
            // Response returns a labeled multi
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let labeled = try decoder.decode(LabeledMulti.self, from: data)
            return MultiReddit(
                name: labeled.data.name,
                path: labeled.data.path,
                descriptionMd: labeled.data.descriptionMd,
                iconUrl: labeled.data.iconUrl,
                subreddits: labeled.data.subreddits.map { $0.name }
            )
        } catch is URLError {
            throw APIError.networkError
        }
    }

    /// Update an existing multireddit
    func updateMultireddit(username: String, name: String, displayName: String? = nil, subreddits: [String]? = nil, descriptionMd: String? = nil, iconName: String? = nil, keyColor: String? = nil, visibility: String? = nil) async throws -> MultiReddit {
        try validateAccessToken()
        guard let url = URL(string: "\(baseURL)/api/multi/user/\(username)/m/\(name)") else { throw APIError.parseError }

        var request = createRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var model: [String: Any] = [:]
        if let displayName { model["display_name"] = displayName }
        if let subreddits { model["subreddits"] = subreddits.map { ["name": $0] } }
        if let descriptionMd { model["description_md"] = descriptionMd }
        if let iconName { model["icon_name"] = iconName }
        if let keyColor { model["key_color"] = keyColor }
        if let visibility { model["visibility"] = visibility }

        request.httpBody = try JSONSerialization.data(withJSONObject: model, options: [])

        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let labeled = try decoder.decode(LabeledMulti.self, from: data)
            return MultiReddit(
                name: labeled.data.name,
                path: labeled.data.path,
                descriptionMd: labeled.data.descriptionMd,
                iconUrl: labeled.data.iconUrl,
                subreddits: labeled.data.subreddits.map { $0.name }
            )
        } catch is URLError {
            throw APIError.networkError
        }
    }

    /// Delete an existing multireddit
    func deleteMultireddit(username: String, name: String) async throws {
        try validateAccessToken()
        guard let url = URL(string: "\(baseURL)/api/multi/user/\(username)/m/\(name)") else { throw APIError.parseError }
        var request = createRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            let (_, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http, allowedStatusCodes: [200, 204])
        } catch is URLError {
            throw APIError.networkError
        }
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
        queryItems.append(URLQueryItem(name: "cache_buster", value: cacheBusterValue()))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.parseError
        }
        
        let request = createRequest(url: url)
        return try await performPostRequest(request: request, endpoint: "r/\(subreddit)")
    }
    
    func fetchHomeFeed(sort: PostSort = .hot, timeFrame: TopTimeFrame? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try validateAccessToken()

        var components = URLComponents(string: "\(baseURL)/\(sort.rawValue).json")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }

        if let timeFrame = timeFrame, sort.supportsTimeFrame {
            queryItems.append(URLQueryItem(name: "t", value: timeFrame.rawValue))
        }
        queryItems.append(URLQueryItem(name: "cache_buster", value: cacheBusterValue()))

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
        queryItems.append(URLQueryItem(name: "cache_buster", value: cacheBusterValue()))
        
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
        queryItems.append(URLQueryItem(name: "cache_buster", value: cacheBusterValue()))
        
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

// MARK: - Post Submission
extension ContentService {
    /// Submit a self (text) post to a subreddit
    func submitTextPost(subreddit: String, title: String, text: String, flairId: String? = nil, flairText: String? = nil) async throws {
        try validateAccessToken()
        guard let url = URL(string: "\(baseURL)/api/submit") else { throw APIError.parseError }
        var request = createPOSTRequest(url: url)
        // Reddit API: kind=self, sr=subreddit (no r/ prefix), title, text, api_type=json
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        var params: [String: String] = [
            "api_type": "json",
            "kind": "self",
            "sr": clean,
            "title": title,
            "text": text
        ]
        if let flairId, !flairId.isEmpty { params["flair_id"] = flairId }
        if let flairText, !flairText.isEmpty { params["flair_text"] = flairText }
        let body = params.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&")
        request.httpBody = body.data(using: String.Encoding.utf8)
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
            // Check json.errors
            struct SubmitResponse: Codable { struct J: Codable { let errors: [[String]]?; let data: DataField?; struct DataField: Codable { let id: String?; let url: String? } }; let json: J }
            if let submit = try? JSONDecoder().decode(SubmitResponse.self, from: data) {
                if let errs = submit.json.errors, !errs.isEmpty { throw APIError.serverError(http.statusCode) }
            }
        } catch is URLError {
            throw APIError.networkError
        } catch { throw error }
    }

    // MARK: - Image/Gallery Submission

    struct MediaLeaseResponse: Codable {
        struct Args: Codable {
            struct Field: Codable { let name: String; let value: String }
            let action: String
            let fields: [Field]
        }
        struct Asset: Codable {
            let assetId: String
            enum CodingKeys: String, CodingKey { case assetId = "asset_id" }
        }
        let args: Args
        let asset: Asset
    }

    /// Upload one image to Reddit via media lease, returning (assetId, ext)
    private func uploadSingleImage(_ data: Data, mimeType: String) async throws -> (id: String, ext: String) {
        try validateAccessToken()
        let ext = mimeType.contains("png") ? "png" : (mimeType.contains("jpeg") || mimeType.contains("jpg") ? "jpg" : "bin")
        // 1) Get lease
        var components = URLComponents(string: baseURL + "/api/media/asset.json")!
        components.queryItems = [ URLQueryItem(name: "raw_json", value: "1") ]
        guard let leaseURL = components.url else { throw APIError.parseError }
        var leaseReq = createPOSTRequest(url: leaseURL)
        leaseReq.httpBody = "filepath=upload.\(ext)&mimetype=\(mimeType)".data(using: .utf8)
        let (leaseData, leaseResp) = try await NetworkManager.shared.session.data(for: leaseReq)
        guard let http = leaseResp as? HTTPURLResponse else { throw APIError.networkError }
        try validateResponse(http)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let lease: MediaLeaseResponse
        do {
            lease = try decoder.decode(MediaLeaseResponse.self, from: leaseData)
        } catch {
            // Fallback manual parse
            guard let obj = try? JSONSerialization.jsonObject(with: leaseData) as? [String: Any],
                  let args = obj["args"] as? [String: Any],
                  let action = args["action"] as? String,
                  let fieldsArr = args["fields"] as? [[String: Any]],
                  let asset = obj["asset"] as? [String: Any],
                  let assetId = asset["asset_id"] as? String else { throw error }
            let fields: [MediaLeaseResponse.Args.Field] = fieldsArr.compactMap { d in
                if let name = d["name"] as? String, let value = d["value"] as? String { return .init(name: name, value: value) }
                return nil
            }
            lease = MediaLeaseResponse(args: .init(action: action, fields: fields), asset: .init(assetId: assetId))
        }

        // 2) Upload multipart to S3
        var dict: [String: String] = [:]
        lease.args.fields.forEach { dict[$0.name] = $0.value }
        let actionStr = lease.args.action.hasPrefix("//") ? "https:" + lease.args.action : lease.args.action
        guard let actionURL = URL(string: actionStr) else { throw APIError.parseError }
        var uploadReq = URLRequest(url: actionURL)
        uploadReq.httpMethod = "POST"
        let boundary = "----MercuryS3_\(UUID().uuidString)"
        uploadReq.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        for (k, v) in dict { append("--\(boundary)\r\n"); append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n") }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.\(ext)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        uploadReq.httpBody = body
        let (_, upResp) = try await NetworkManager.shared.session.data(for: uploadReq)
        guard let upHTTP = upResp as? HTTPURLResponse, (200..<400).contains(upHTTP.statusCode) else { throw APIError.networkError }
        return (lease.asset.assetId, ext)
    }

    /// Attempt to submit a single-image post using kind=image and preview URL. Fallback to richtext if needed.
    func submitImagePost(subreddit: String, title: String, caption: String?, images: [UIImage], flairId: String? = nil, flairText: String? = nil) async throws {
        try validateAccessToken()
        guard !images.isEmpty else { throw APIError.parseError }
        // Prepare data up to 20 images
        let prepared: [(Data, String)] = images.prefix(20).compactMap { (img) -> (Data, String)? in
            if let png = img.pngData() { return (png, "image/png") }
            if let jpg = img.jpegData(compressionQuality: 0.92) { return (jpg, "image/jpeg") }
            return nil
        }
        guard !prepared.isEmpty else { throw APIError.parseError }

        // Upload all images to get asset ids
        var assets: [(id: String, ext: String)] = []
        for (data, mime) in prepared { assets.append(try await uploadSingleImage(data, mimeType: mime)) }

        if assets.count == 1 {
            // Try native image post first
            let a = assets[0]
            let imageURL = "https://preview.redd.it/\(a.id).\(a.ext)"
            guard let url = URL(string: baseURL + "/api/submit") else { throw APIError.parseError }
            var req = createPOSTRequest(url: url)
            let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
            var params: [String: String] = [
                "api_type": "json",
                "kind": "image",
                "sr": clean,
                "title": title,
                "url": imageURL
            ]
            if let flairId, !flairId.isEmpty { params["flair_id"] = flairId }
            if let flairText, !flairText.isEmpty { params["flair_text"] = flairText }
            let body = params.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&")
            req.httpBody = body.data(using: .utf8)
            do {
                let (data, resp) = try await NetworkManager.shared.session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw APIError.networkError }
                try validateResponse(http)
                // Validate JSON errors array
                struct SubmitResponse: Codable { struct J: Codable { let errors: [[String]]?; let data: DataField?; struct DataField: Codable { let id: String?; let url: String? } }; let json: J }
                if let submit = try? JSONDecoder().decode(SubmitResponse.self, from: data), let errs = submit.json.errors, !errs.isEmpty {
                    throw APIError.serverError(http.statusCode)
                }
                return
            } catch {
                // Fallback to richtext self-post embedding
                try await submitRichtextImagePost(subreddit: clean, title: title, caption: caption, assets: assets, flairId: flairId, flairText: flairText)
            }
        } else {
            // Gallery-like: richtext self post embedding multiple media nodes
            let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
            try await submitRichtextImagePost(subreddit: clean, title: title, caption: caption, assets: assets, flairId: flairId, flairText: flairText)
        }
    }

    private func submitRichtextImagePost(subreddit: String, title: String, caption: String?, assets: [(id: String, ext: String)], flairId: String?, flairText: String?) async throws {
        try validateAccessToken()
        guard let url = URL(string: baseURL + "/api/submit?raw_json=1") else { throw APIError.parseError }
        var request = createPOSTRequest(url: url)
        var document: [[String: Any]] = []
        if let caption = caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            document.append(["e": "paragraph", "c": [["e": "text", "t": caption]]])
        }
        for a in assets { document.append(["e": "media", "id": a.id, "t": "image"]) }
        let rtjson: [String: Any] = ["document": document]
        let rtData = try JSONSerialization.data(withJSONObject: rtjson, options: [])
        guard let jsonString = String(data: rtData, encoding: .utf8) else { throw APIError.parseError }
        var params: [String: String] = [
            "api_type": "json",
            "kind": "self",
            "sr": subreddit,
            "title": title,
            "richtext_json": jsonString
        ]
        if let flairId, !flairId.isEmpty { params["flair_id"] = flairId }
        if let flairText, !flairText.isEmpty { params["flair_text"] = flairText }
        let body = params.map { key, value in
            "\(key)=\(Self.formEncode(value))"
        }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        let (respData, response) = try await NetworkManager.shared.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        try validateResponse(http)
        // Validate JSON success
        struct SubmitResponse: Codable { struct J: Codable { let errors: [[String]]? }; let json: J }
        if let submit = try? JSONDecoder().decode(SubmitResponse.self, from: respData), let errs = submit.json.errors, !errs.isEmpty {
            throw APIError.serverError(http.statusCode)
        }
    }

    private func cacheBusterValue() -> String {
        let milliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        return String(milliseconds)
    }
}

extension ContentService {
    // MARK: - Subreddit Flair + Requirements

    func fetchLinkFlairs(subreddit: String) async throws -> [LinkFlair] {
        try validateAccessToken()
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        guard let url = URL(string: baseURL + "/r/\(clean)/api/link_flair_v2.json?is_newlink=true&raw_json=1") else { throw APIError.parseError }
        let req = createRequest(url: url)
        print("[FlairFetch] GET \(url.absoluteString)")
        let (data, resp) = try await NetworkManager.shared.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError }
        print("[FlairFetch] status=\(http.statusCode)")
        try validateResponse(http)
        if let decoded = decodeLinkFlairs(from: data) {
            print("[FlairFetch] decoded count=\(decoded.count)")
            return decoded
        }
        return []
    }

    // Fallback endpoint removed per request; only v2 OAuth endpoint is used.

    private func decodeLinkFlairs(from data: Data) -> [LinkFlair]? {
        // Attempt strict decode first
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let flairs = try? decoder.decode([LinkFlair].self, from: data) {
            return flairs
        }
        // Fallback best-effort decode
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        var results: [LinkFlair] = []
        for item in arr {
            guard let id = item["id"] as? String else { continue }
            let text = (item["text"] as? String) ?? ""
            let bg = item["background_color"] as? String
            let tc = item["text_color"] as? String
            let editable = item["text_editable"] as? Bool
            let modOnly = (item["mod_only"] as? Bool)
            results.append(LinkFlair(id: id, text: text, backgroundColor: bg, textColor: tc, textEditable: editable, modOnly: modOnly))
        }
        return results
    }

    func fetchPostRequirements(subreddit: String, postType: String? = nil) async throws -> PostRequirements? {
        try validateAccessToken()
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        var comps = URLComponents(string: baseURL + "/api/v1/\(clean)/post_requirements")!
        var items: [URLQueryItem] = []
        if let postType, !postType.isEmpty { items.append(URLQueryItem(name: "post_type", value: postType)) }
        comps.queryItems = items.isEmpty ? nil : items
        guard let url = comps.url else { return nil }
        let req = createRequest(url: url)
        print("[PostReq] GET \(url.absoluteString)")
        let (data, resp) = try await NetworkManager.shared.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError }
        print("[PostReq] status=\(http.statusCode)")
        try validateResponse(http)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let reqs = try? decoder.decode(PostRequirements.self, from: data)
        if let r = reqs { print("[PostReq] isFlairRequired=\(r.isFlairRequired ?? false)") } else { print("[PostReq] decode failed") }
        return reqs
    }

    // MARK: - Flair Selector (existing posts)
    /// Fetches flair options for an existing submission via flairselector.
    /// - Parameters:
    ///   - subreddit: target subreddit (with or without r/)
    ///   - linkFullname: fullname like "t3_abcdef"
    func fetchFlairSelector(subreddit: String, linkFullname: String) async throws -> [LinkFlair] {
        try validateAccessToken()
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        guard let url = URL(string: baseURL + "/r/\(clean)/api/flairselector.json?link=\(linkFullname)&raw_json=1") else { throw APIError.parseError }
        let req = createRequest(url: url)
        print("[FlairSelector] GET \(url.absoluteString)")
        let (data, resp) = try await NetworkManager.shared.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError }
        print("[FlairSelector] status=\(http.statusCode)")
        try validateResponse(http)
        // Flexible decode: prefer keys from v2, fallback to common keys
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let choices = arr["choices"] as? [[String: Any]] { return parseFlairChoices(choices) }
            if let choices = arr["options"] as? [[String: Any]] { return parseFlairChoices(choices) }
        }
        // Some implementations return an array directly
        if let choices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return parseFlairChoices(choices)
        }
        return []
    }

    private func parseFlairChoices(_ choices: [[String: Any]]) -> [LinkFlair] {
        var out: [LinkFlair] = []
        for c in choices {
            let id = (c["flair_template_id"] as? String) ?? (c["template_id"] as? String) ?? (c["id"] as? String)
            let text = (c["text"] as? String) ?? (c["flair_text"] as? String) ?? ""
            let bg = (c["background_color"] as? String) ?? (c["flair_background_color"] as? String)
            let tc = (c["text_color"] as? String) ?? (c["flair_text_color"] as? String)
            let editable = (c["text_editable"] as? Bool) ?? (c["flair_text_editable"] as? Bool)
            let modOnly = (c["mod_only"] as? Bool) ?? (c["flair_mod_only"] as? Bool)
            if let id = id {
                out.append(LinkFlair(id: id, text: text, backgroundColor: bg, textColor: tc, textEditable: editable, modOnly: modOnly))
            }
        }
        print("[FlairSelector] parsed choices=\(out.count)")
        return out
    }

    /// Applies a flair to an existing submission using selectflair.
    func selectFlair(subreddit: String, linkFullname: String, flairTemplateId: String, text: String? = nil) async throws {
        try validateAccessToken()
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        guard let url = URL(string: baseURL + "/r/\(clean)/api/selectflair") else { throw APIError.parseError }
        var req = createPOSTRequest(url: url)
        var params: [String: String] = [
            "api_type": "json",
            "link": linkFullname,
            "flair_template_id": flairTemplateId
        ]
        if let text, !text.isEmpty { params["text"] = text }
        req.httpBody = params.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        print("[SelectFlair] POST \(url.absoluteString) link=\(linkFullname) template=\(flairTemplateId)")
        let (data, resp) = try await NetworkManager.shared.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError }
        print("[SelectFlair] status=\(http.statusCode)")
        try validateResponse(http)
        // Optional: check errors array
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let json = obj["json"] as? [String: Any],
           let errors = json["errors"] as? [[Any]], !errors.isEmpty {
            print("[SelectFlair] server errors=\(errors)")
            throw APIError.serverError(http.statusCode)
        }
    }

    static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=%\" <>?{}|^`\\")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }


    /// Submit a link post to a subreddit (optionally with body text)
    func submitLinkPost(subreddit: String, title: String, url: String, flairId: String? = nil, flairText: String? = nil) async throws {
        try validateAccessToken()
        guard let endpoint = URL(string: "\(baseURL)/api/submit") else { throw APIError.parseError }
        var request = createPOSTRequest(url: endpoint)
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        var params: [String: String] = [
            "api_type": "json",
            "kind": "link",
            "sr": clean,
            "title": title,
            "url": url
        ]
        if let flairId, !flairId.isEmpty { params["flair_id"] = flairId }
        if let flairText, !flairText.isEmpty { params["flair_text"] = flairText }
        let body = params.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&")
        request.httpBody = body.data(using: String.Encoding.utf8)
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
            struct SubmitResponse: Codable { struct J: Codable { let errors: [[String]]?; let data: DataField?; struct DataField: Codable { let id: String?; let url: String? } }; let json: J }
            if let submit = try? JSONDecoder().decode(SubmitResponse.self, from: data) {
                if let errs = submit.json.errors, !errs.isEmpty { throw APIError.serverError(http.statusCode) }
            }
        } catch is URLError { throw APIError.networkError }
    }
    
    private static func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
