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
    private(set) var rootAfter: String? = nil
    var hasMoreRootComments: Bool { rootAfter != nil }
    private var rootRemainingChildren: [String] = []
    
    func loadInitialComments(_ comments: [RedditComment], moreObjects: [MoreComments], rootAfter: String?) {
        self.allComments = comments
        self.rootAfter = rootAfter
        self.rootRemainingChildren = []
        
        // Decide root-level strategy:
        // 1) If API provided an after token, use pagination.
        // 2) Else, consolidate any root-level MoreComments into a single button using their children IDs.
        if shouldAddRootLevelLoadMore(comments: comments) {
            let afterToken = rootAfter ?? ""
            let rootLoadMore = MoreComments(
                count: 25,
                name: "root_pagination",
                rawId: "root_pagination",
                parentId: nil,
                depth: 0,
                children: afterToken.isEmpty ? [] : [afterToken]
            )
            self.moreObjects = [rootLoadMore]
            print("🔍 Added root-level pagination with after=\(afterToken.isEmpty ? "<none>" : afterToken)")
        } else {
            // Collect root-level MoreComments from API
            let rootMores = moreObjects.filter { $0.depth == 0 }
            if !rootMores.isEmpty {
                let combinedChildren = rootMores.flatMap { $0.children }
                self.rootRemainingChildren = combinedChildren
                let slice = Array(combinedChildren.prefix(25))
                if !slice.isEmpty {
                    let consolidated = MoreComments(
                        count: slice.count,
                        name: "root_more_children",
                        rawId: "root_more_children",
                        parentId: nil,
                        depth: 0,
                        children: slice
                    )
                    self.moreObjects = [consolidated]
                    print("🔍 Added root-level morechildren with \(combinedChildren.count) total ids (showing \(slice.count))")
                } else {
                    self.moreObjects = []
                }
            } else {
                self.moreObjects = []
            }
        }
        
        // Build comment threads by organizing into parent-child relationships
        commentThreads = buildCommentThreads(from: comments)
    }
    
    /// Append another page of root-level comments and update pagination state
    func appendRootPage(newComments: [RedditComment], nextAfter: String?) {
        // Update stored comments
        allComments.append(contentsOf: newComments)
        rootAfter = nextAfter
        
        // Append threads in API order (preserve current sort order from server)
        let newThreads = newComments.filter { $0.depth == 0 }.map { CommentThread(parentComment: $0) }
        commentThreads.append(contentsOf: newThreads)
        
        // Rebuild root-level More object depending on nextAfter
        if let after = nextAfter {
            moreObjects = [
                MoreComments(
                    count: 25,
                    name: "root_pagination",
                    rawId: "root_pagination",
                    parentId: nil,
                    depth: 0,
                    children: [after]
                )
            ]
            print("🔍 Updated root pagination with next after=\(after)")
        } else {
            moreObjects = []
            print("🔍 Reached end of root pagination (no after)")
        }
    }

    /// Append a page of root-level comments loaded via morechildren and update remaining ids
    func appendRootChildrenPage(newComments: [RedditComment], consumedCount: Int) {
        // Update stored comments and threads
        allComments.append(contentsOf: newComments)
        let newThreads = newComments.filter { $0.depth == 0 }.map { CommentThread(parentComment: $0) }
        commentThreads.append(contentsOf: newThreads)
        
        // Consume from remaining children and refresh the More object
        if consumedCount > 0 && consumedCount <= rootRemainingChildren.count {
            rootRemainingChildren.removeFirst(consumedCount)
        }
        if rootRemainingChildren.isEmpty {
            moreObjects = []
            print("🔍 Root morechildren exhausted; hiding button")
        } else {
            let nextSlice = Array(rootRemainingChildren.prefix(25))
            let consolidated = MoreComments(
                count: nextSlice.count,
                name: "root_more_children",
                rawId: "root_more_children",
                parentId: nil,
                depth: 0,
                children: nextSlice
            )
            moreObjects = [consolidated]
            print("🔍 Root morechildren remaining: \(rootRemainingChildren.count); showing next \(nextSlice.count)")
        }
    }

    private func shouldAddRootLevelLoadMore(comments: [RedditComment]) -> Bool {
        // If Reddit API supplies an "after" token, there are more root comments
        return rootAfter != nil && !comments.filter { $0.depth == 0 }.isEmpty
    }
    
    private func buildCommentThreads(from comments: [RedditComment]) -> [CommentThread] {
        // Reddit API already provides proper threading via replies structure
        // We just need to create CommentThread objects for top-level comments
        let topLevelComments = comments.filter { $0.depth == 0 }
        
        let threads = topLevelComments.map { topComment in
            CommentThread(parentComment: topComment)
        }
        
        return threads
    }
    
    // No longer needed - Reddit API provides proper threading
    
    func insertMoreComments(_ newComments: [RedditComment], replacingMoreId: String) {
        // Find and remove the more object
        moreObjects.removeAll { $0.id == replacingMoreId }
        
        // Add new top-level comments as new threads
        let newTopLevelComments = newComments.filter { $0.depth == 0 }
        let newThreads = newTopLevelComments.map { CommentThread(parentComment: $0) }
        
        commentThreads.append(contentsOf: newThreads)
        // Keep API order
    }

}
