//
//  CommentThread.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import Foundation

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
        var threads: [CommentThread] = []
        let allComments = flattenAllComments(comments)
        
        // Find top-level comments (depth 0 or those without parents in this set)
        let topLevelComments = allComments.filter { comment in
            comment.depth == 0 || 
            !allComments.contains { $0.id == comment.parentId?.replacingOccurrences(of: "t1_", with: "") }
        }
        
        // Create threads for each top-level comment
        for topComment in topLevelComments {
            let thread = CommentThread(parentComment: topComment, allComments: allComments)
            threads.append(thread)
        }
        
        return threads.sorted { $0.parentComment.score > $1.parentComment.score }
    }
    
    private func flattenAllComments(_ comments: [RedditComment]) -> [RedditComment] {
        var flattened: [RedditComment] = []
        
        for comment in comments {
            flattened.append(comment)
            
            // Add nested replies
            if let replies = comment.replies {
                let nestedComments = replies.comments
                flattened.append(contentsOf: flattenAllComments(nestedComments))
            }
        }
        
        return flattened
    }
    
    func insertMoreComments(_ newComments: [RedditComment], replacingMoreId: String) {
        // Find and remove the more object
        moreObjects.removeAll { $0.id == replacingMoreId }
        
        // Rebuild threads with new comments included
        let allCurrentComments = commentThreads.flatMap { thread in
            [thread.parentComment] + thread.replies
        }
        let allComments = allCurrentComments + newComments
        commentThreads = buildCommentThreads(from: allComments)
    }
}