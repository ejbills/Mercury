//
//  InboxService.swift
//  Mercury
//
//  Created by AI Assistant on 8/19/25.
//

import Foundation

/// Service responsible for fetching and mapping Reddit inbox data
class InboxService: BaseRedditService {
    enum Category {
        case all
        case unread
        case messages
        case mentions
        case replies
        
        var path: String {
            switch self {
            case .all: return "/message/inbox.json"
            case .unread: return "/message/unread.json"
            case .messages: return "/message/messages.json"
            case .mentions: return "/message/mentions.json"
            case .replies: return "/message/comments.json"
            }
        }
    }
    
    struct Page {
        let items: [InboxItem]
        let after: String?
    }
    
    func fetch(category: Category, after: String? = nil, limit: Int = 25) async throws -> Page {
        try validateAccessToken()
        
        var components = URLComponents(string: baseURL + category.path)!
        var queryItems: [URLQueryItem] = [
            .init(name: "limit", value: String(limit))
        ]
        if let after { queryItems.append(.init(name: "after", value: after)) }
        components.queryItems = queryItems
        
        guard let url = components.url else { throw APIError.parseError }
        let request = createRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let listing = try decoder.decode(MessageListingResponse.self, from: data)
            
            let items = listing.data.children.compactMap { thing -> InboxItem? in
                mapThingToInboxItem(thing)
            }
            
            return Page(items: items, after: listing.data.after)
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw error
        }
    }
    
    // Map raw API message/comment/mention to unified inbox item model
    private func mapThingToInboxItem(_ thing: MessageThing) -> InboxItem? {
        let raw = thing.data
        let id = raw.id
        let isUnread = raw.new ?? false
        let createdDate = Date(timeIntervalSince1970: (raw.createdUtc ?? 0))
        let author = raw.author ?? "[deleted]"
        let subreddit = raw.subreddit
        let contextURL = buildContextURL(from: raw.context)
        
        switch thing.kind {
        case "t4": // Private message
            let subject = raw.subject ?? "Message"
            let body = raw.body ?? ""
            return InboxItem(
                id: id,
                fullName: raw.name,
                subject: subject,
                body: body,
                author: author,
                subreddit: subreddit,
                isUnread: isUnread,
                created: createdDate,
                type: .privateMessage,
                contextURL: contextURL
            )
        case "t1": // Comment-based (reply or mention)
            // Type may distinguish reply vs mention
            let apiType = (raw.type ?? "").lowercased()
            let inferredType: InboxItem.ItemType = apiType.contains("mention") ? .mention : .commentReply
            let subject = raw.subject ?? (inferredType == .mention ? "Mention" : "Comment reply")
            let body = raw.body ?? ""
            return InboxItem(
                id: id,
                fullName: raw.name,
                subject: subject,
                body: body,
                author: author,
                subreddit: subreddit,
                isUnread: isUnread,
                created: createdDate,
                type: inferredType,
                contextURL: contextURL
            )
        default:
            return nil
        }
    }
    
    private func buildContextURL(from contextPath: String?) -> URL? {
        guard let contextPath, !contextPath.isEmpty else { return nil }
        // API returns relative paths like "/r/sub/comments/abc/…"
        return URL(string: "https://reddit.com\(contextPath)")
    }
    
    // MARK: - Actions
    
    /// Reply to a private message (t4_ thing)
    func replyToMessage(fullname: String, text: String) async throws {
        try validateAccessToken()
        guard let url = URL(string: "\(baseURL)/api/comment") else { throw APIError.parseError }
        var request = createPOSTRequest(url: url)
        // Reddit expects `thing_id` or `parent` for replies; use `thing_id` with fullname
        let parameters = [
            "api_type": "json",
            "thing_id": fullname,
            "text": text
        ]
        let postData = parameters.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        request.httpBody = postData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
        } catch is URLError {
            throw APIError.networkError
        } catch { throw error }
    }
    
    /// Compose a new private message to a username
    func composeMessage(to username: String, subject: String, text: String) async throws {
        try validateAccessToken()
        guard let url = URL(string: "\(baseURL)/api/compose") else { throw APIError.parseError }
        var request = createPOSTRequest(url: url)
        let parameters = [
            "api_type": "json",
            "to": username,
            "subject": subject,
            "text": text
        ]
        let body = parameters.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            try validateResponse(http)
        } catch is URLError {
            throw APIError.networkError
        } catch { throw error }
    }
    
    private static func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
