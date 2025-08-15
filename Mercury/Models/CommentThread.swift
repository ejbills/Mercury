//
//  CommentThread.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import Foundation

/// Represents a comment thread containing a top-level comment
struct CommentThread {
    let parentComment: RedditComment
    
    // CommentThread now only represents the top-level comment
    // Replies are handled by the Reddit API's nested structure
    init(parentComment: RedditComment) {
        self.parentComment = parentComment
    }
}

/// Represents a comment thread item that can be either a comment or a "more" object
enum CommentThreadItem: Identifiable {
    case comment(RedditComment)
    case more(MoreComments)
    
    var id: String {
        switch self {
        case .comment(let comment):
            return comment.id
        case .more(let more):
            return more.id
        }
    }
    
    var depth: Int {
        switch self {
        case .comment(let comment):
            return comment.depth
        case .more(let more):
            return more.depth
        }
    }
}

/// Helper class to manage comment threading and card organization
@Observable
class CommentThreadManager {
    private(set) var commentThreads: [CommentThread] = []
    private(set) var moreObjects: [MoreComments] = []
    
    func loadInitialComments(_ comments: [RedditComment], moreObjects: [MoreComments]) {
        self.moreObjects = moreObjects
        
        // Build comment threads by organizing into parent-child relationships
        commentThreads = buildCommentThreads(from: comments)
    }
    
    private func buildCommentThreads(from comments: [RedditComment]) -> [CommentThread] {
        // Reddit API already provides proper threading via replies structure
        // We just need to create CommentThread objects for top-level comments
        let topLevelComments = comments.filter { $0.depth == 0 }
        
        let threads = topLevelComments.map { topComment in
            CommentThread(parentComment: topComment)
        }
        
        return threads.sorted { $0.parentComment.score > $1.parentComment.score }
    }
    
    // No longer needed - Reddit API provides proper threading
    
    func insertMoreComments(_ newComments: [RedditComment], replacingMoreId: String) {
        // Find and remove the more object
        moreObjects.removeAll { $0.id == replacingMoreId }
        
        // Add new top-level comments as new threads
        let newTopLevelComments = newComments.filter { $0.depth == 0 }
        let newThreads = newTopLevelComments.map { CommentThread(parentComment: $0) }
        
        commentThreads.append(contentsOf: newThreads)
        // Re-sort by score
        commentThreads.sort { $0.parentComment.score > $1.parentComment.score }
    }

}
