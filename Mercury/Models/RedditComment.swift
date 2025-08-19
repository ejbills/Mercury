//
//  RedditComment.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import Foundation

struct RedditComment: Codable, Identifiable, Hashable {
    let id: String
    let subreddit: String?
    let author: String
    let body: String
    let bodyHtml: String?
    let score: Int
    let depth: Int
    let created: Double?
    let createdUtc: Double?
    let edited: EditedData?
    let distinguished: String?
    let stickied: Bool
    let saved: Bool
    let likes: Bool?
    let permalink: String
    let parentId: String?
    let linkId: String?
    let isSubmitter: Bool
    let scoreHidden: Bool
    let controversiality: Int
    let authorFlairText: String?
    let gilded: Int
    let collapsed: Bool
    let collapsedReason: String?
    let archived: Bool
    let locked: Bool
    var replies: CommentReplies?
    
    // Local state management
    var currentVoteState: VoteState = .neutral
    var displayScore: Int
    var isCollapsed: Bool = false
    
    enum VoteState {
        case upvoted
        case downvoted  
        case neutral
    }
    
    enum CodingKeys: String, CodingKey {
        case id, subreddit, author, body, score, depth, created, permalink, distinguished, stickied, saved, likes, gilded, collapsed, archived, locked, replies
        case bodyHtml = "body_html"
        case createdUtc = "created_utc"
        case edited
        case parentId = "parent_id"
        case linkId = "link_id"
        case isSubmitter = "is_submitter"
        case scoreHidden = "score_hidden"
        case controversiality
        case authorFlairText = "author_flair_text"
        case collapsedReason = "collapsed_reason"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        subreddit = try container.decodeIfPresent(String.self, forKey: .subreddit)
        author = try container.decode(String.self, forKey: .author)
        body = try container.decode(String.self, forKey: .body)
        bodyHtml = try container.decodeIfPresent(String.self, forKey: .bodyHtml)
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        created = try container.decodeIfPresent(Double.self, forKey: .created)
        createdUtc = try container.decodeIfPresent(Double.self, forKey: .createdUtc)
        edited = try container.decodeIfPresent(EditedData.self, forKey: .edited)
        distinguished = try container.decodeIfPresent(String.self, forKey: .distinguished)
        stickied = try container.decodeIfPresent(Bool.self, forKey: .stickied) ?? false
        saved = try container.decodeIfPresent(Bool.self, forKey: .saved) ?? false
        likes = try container.decodeIfPresent(Bool.self, forKey: .likes)
        permalink = try container.decode(String.self, forKey: .permalink)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        linkId = try container.decodeIfPresent(String.self, forKey: .linkId)
        isSubmitter = try container.decodeIfPresent(Bool.self, forKey: .isSubmitter) ?? false
        scoreHidden = try container.decodeIfPresent(Bool.self, forKey: .scoreHidden) ?? false
        controversiality = try container.decodeIfPresent(Int.self, forKey: .controversiality) ?? 0
        authorFlairText = try container.decodeIfPresent(String.self, forKey: .authorFlairText)
        gilded = try container.decodeIfPresent(Int.self, forKey: .gilded) ?? 0
        collapsed = try container.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        collapsedReason = try container.decodeIfPresent(String.self, forKey: .collapsedReason)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        replies = try container.decodeIfPresent(CommentReplies.self, forKey: .replies)
        
        // Initialize local state
        displayScore = score
        if let likes = likes {
            currentVoteState = likes ? .upvoted : .downvoted
        } else {
            currentVoteState = .neutral
        }
    }
    
    var createdDate: Date {
        if let createdUtc = createdUtc {
            return Date(timeIntervalSince1970: createdUtc)
        } else if let created = created {
            return Date(timeIntervalSince1970: created)
        } else {
            return Date()
        }
    }
    
    var timeAgo: String {
        guard let createdUtc = createdUtc ?? created else {
            return "now"
        }
        
        let now = Date()
        let createdDate = Date(timeIntervalSince1970: createdUtc)
        let timeInterval = now.timeIntervalSince(createdDate)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 2592000 {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return "\(months)mo"
        } else {
            let years = Int(timeInterval / 31536000)
            return "\(years)y"
        }
    }
    
    var scoreText: String {
        if scoreHidden {
            return "•"
        }
        
        let score = max(0, displayScore)
        if score >= 1000 {
            let kScore = Double(score) / 1000.0
            return String(format: "%.1fk", kScore)
        } else {
            return String(score)
        }
    }
    
    var permalinkURL: String {
        return "https://reddit.com\(permalink)"
    }
    
    var canVote: Bool {
        return !archived && !locked
    }
    
    mutating func applyVote(_ voteState: VoteState) {
        let oldState = currentVoteState
        currentVoteState = voteState
        
        // Update display score based on vote change
        switch (oldState, voteState) {
        case (.neutral, .upvoted):
            displayScore += 1
        case (.neutral, .downvoted):
            displayScore -= 1
        case (.upvoted, .neutral):
            displayScore -= 1
        case (.upvoted, .downvoted):
            displayScore -= 2
        case (.downvoted, .neutral):
            displayScore += 1
        case (.downvoted, .upvoted):
            displayScore += 2
        case (.neutral, .neutral), (.upvoted, .upvoted), (.downvoted, .downvoted):
            break // No change
        }
    }
    
    mutating func revertVote(to originalState: VoteState, originalScore: Int) {
        currentVoteState = originalState
        displayScore = originalScore
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RedditComment, rhs: RedditComment) -> Bool {
        return lhs.id == rhs.id
    }
}

enum CommentSort: String, CaseIterable {
    case best = "best"
    case top = "top"
    case new = "new"
    case controversial = "controversial"
    case old = "old"
    case qa = "qa"
    
    var displayName: String {
        switch self {
        case .best: return "Best"
        case .top: return "Top"
        case .new: return "New"
        case .controversial: return "Controversial"
        case .old: return "Old"
        case .qa: return "Q&A"
        }
    }
}

enum CommentReplies: Codable {
    case listing(CommentResponse)
    case empty(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .empty(stringValue)
        } else if let listingValue = try? container.decode(CommentResponse.self) {
            self = .listing(listingValue)
        } else {
            self = .empty("")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .listing(let listing):
            try container.encode(listing)
        case .empty(let string):
            try container.encode(string)
        }
    }
    
    var comments: [RedditComment] {
        switch self {
        case .listing(let response):
            return response.flattenedComments
        case .empty:
            return []
        }
    }
}

struct CommentResponse: Codable {
    let data: CommentListData
    
    var flattenedComments: [RedditComment] {
        var allComments: [RedditComment] = []
        
        func collectComments(from children: [CommentChild]) {
            for child in children {
                switch child.data {
                case .comment(let comment):
                    allComments.append(comment)
                    if let replies = comment.replies {
                        switch replies {
                        case .empty:
                            break
                        case .listing(let commentResponse):
                            collectComments(from: commentResponse.data.children)
                        }
                    }
                case .more(let more):
                    // Filter out dummy entries (t3 posts)
                    if !more.name.isEmpty {
                        // Don't add MoreComments to the flattened list
                    }
                }
            }
        }
        
        collectComments(from: data.children)
        return allComments
    }
    
    var moreComments: [MoreComments] {
        // Recursively collect MoreComments from the entire comment tree
        var allMoreComments: [MoreComments] = []
        
        func collectMoreComments(from children: [CommentChild]) {
            for child in children {
                switch child.data {
                case .comment(let comment):
                    // Recursively check this comment's replies
                    if let replies = comment.replies {
                        switch replies {
                        case .empty:
                            break
                        case .listing(let response):
                            collectMoreComments(from: response.data.children)
                        }
                    }
                case .more(let more):
                    // Only filter out completely empty entries (t3 posts)
                    if more.name.isEmpty && more.children.isEmpty && more.count == 0 {
                    } else {
                        allMoreComments.append(more)
                    }
                }
            }
        }
        
        collectMoreComments(from: data.children)
        return allMoreComments
    }
}

struct CommentListData: Codable {
    let children: [CommentChild]
    let after: String?
    let before: String?
}

struct CommentChild: Codable {
    let kind: String
    let data: CommentData
    
    enum CommentData: Codable {
        case comment(RedditComment)
        case more(MoreComments)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(String.self, forKey: .kind)
            
            switch kind {
            case "t1": // Comment
                let comment = try container.decode(RedditComment.self, forKey: .data)
                self = .comment(comment)
            case "more": // More comments
                let more = try container.decode(MoreComments.self, forKey: .data)
                self = .more(more)
            case "t3": // Post - skip this by creating a dummy more object
                self = .more(MoreComments(count: 0, name: "", rawId: "", parentId: nil, depth: 0, children: []))
            default:
                throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown comment kind: \(kind)")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .comment(let comment):
                try container.encode("t1", forKey: .kind)
                try container.encode(comment, forKey: .data)
            case .more(let more):
                try container.encode("more", forKey: .kind)
                try container.encode(more, forKey: .data)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case kind, data
        }
    }
    
    // Simple memberwise initializer
    init(kind: String, data: CommentData) {
        self.kind = kind
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        
        switch kind {
        case "t1": // Comment
            let comment = try container.decode(RedditComment.self, forKey: .data)
            data = .comment(comment)
        case "more": // More comments
            let more = try container.decode(MoreComments.self, forKey: .data)
            data = .more(more)
        case "t3": // Post - skip this by creating a dummy more object
            data = .more(MoreComments(count: 0, name: "", rawId: "", parentId: nil, depth: 0, children: []))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown comment kind: \(kind)")
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case kind, data
    }
}

struct MoreComments: Codable {
    let count: Int
    let name: String
    let rawId: String
    let parentId: String?
    let depth: Int
    let children: [String]
    
    // Computed property to get the actual ID - use name if id is empty/underscore
    var id: String {
        if rawId.isEmpty || rawId == "_" {
            return name.isEmpty ? "_" : name
        }
        return rawId
    }
    
    enum CodingKeys: String, CodingKey {
        case count, name, depth, children
        case rawId = "id"
        case parentId = "parent_id"
    }
}
