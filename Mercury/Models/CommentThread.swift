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
    private var allComments: [RedditComment] = []
    
    func loadInitialComments(_ comments: [RedditComment], moreObjects: [MoreComments]) {
        self.allComments = comments
        
        // Use parsed MoreComments from API response, plus generate root-level load more if needed
        var allMoreObjects = moreObjects
        
        // Check if we should add root-level load more
        if shouldAddRootLevelLoadMore(comments: comments) {
            let rootCommentIds = comments.filter { $0.depth == 0 }.map { $0.id }
            let rootLoadMore = MoreComments(
                count: rootCommentIds.count,
                name: "root_load_more", 
                rawId: "root_load_more",
                parentId: nil,
                depth: 0,
                children: rootCommentIds // Pass current root comment IDs for pagination
            )
            allMoreObjects.append(rootLoadMore)
            print("🔍 Added root-level load more with \(rootCommentIds.count) existing comment IDs")
        }
        
        self.moreObjects = allMoreObjects
        
        // Build comment threads by organizing into parent-child relationships
        commentThreads = buildCommentThreads(from: comments)
    }
    
    private func shouldAddRootLevelLoadMore(comments: [RedditComment]) -> Bool {
        // TODO: This should check the "after" field from the Reddit API response
        // If "after" is not null, there are more comments to load
        // For now, return false until we implement proper pagination
        return false
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
