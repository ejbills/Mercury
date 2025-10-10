import Foundation

/// Unified model used by the app to render inbox entries
struct InboxItem: Identifiable, Equatable {
    let id: String
    let fullName: String?
    let subject: String
    let body: String
    let author: String
    let subreddit: String?
    let isUnread: Bool
    let created: Date
    let type: ItemType
    let contextURL: URL?
    var authorIconURL: URL?
    
    enum ItemType {
        case privateMessage
        case commentReply
        case mention
    }

    var canBeDeleted: Bool {
        // Only private messages can be deleted from inbox
        // Comment replies and mentions are actual comments and require different handling
        type == .privateMessage
    }

    var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(created)
        if timeInterval < 60 { return "now" }
        if timeInterval < 3600 { return "\(Int(timeInterval / 60))m" }
        if timeInterval < 86400 { return "\(Int(timeInterval / 3600))h" }
        if timeInterval < 2592000 { return "\(Int(timeInterval / 86400))d" }
        if timeInterval < 31536000 { return "\(Int(timeInterval / 2592000))mo" }
            return "\(Int(timeInterval / 31536000))y"
    }
}

// MARK: - Raw API decoding models

/// Generic listing wrapper for message endpoints
struct MessageListingResponse: Codable {
    let data: MessageListingData
}

struct MessageListingData: Codable {
    let children: [MessageThing]
    let after: String?
    let before: String?
}

struct MessageThing: Codable {
    let kind: String
    let data: RawMessage
}

/// Superset of fields used from both private messages (t4) and comment-based items (t1)
struct RawMessage: Codable {
    let id: String
    let name: String?
    let subject: String?
    let body: String?
    let author: String?
    let dest: String?
    let subreddit: String?
    let new: Bool?
    let createdUtc: Double?
    let type: String? // e.g. "comment_reply", "username_mention"
    let context: String? // relative URL path to context
    let linkTitle: String? // title associated with comment/mention
}
