//
//  CommentThreadView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct CommentThreadView: View {
    let comments: [RedditComment]
    let post: RedditPost
    let sort: CommentSort
    
    // Unified flat state management for entire thread
    @State private var flatItems: [FlatCommentItem] = []
    @State private var loadingMoreIds: Set<String> = []
    @State private var collapsedComments: Set<String> = []
    
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(comments: [RedditComment], post: RedditPost, sort: CommentSort) {
        self.comments = comments
        self.post = post
        self.sort = sort
        
        // Initialize flat structure from all comments
        let initialFlatItems = Self.flattenAllComments(comments: comments)
        self._flatItems = State(initialValue: initialFlatItems)
    }
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(flatItems.enumerated()), id: \.element.id) { index, item in
                
                switch item {
                case .comment(let flatComment):
                    if shouldShowComment(flatComment) {
                        CommentView(
                            comment: flatComment.comment,
                            depth: flatComment.depth,
                            post: post,
                            isCollapsed: collapsedComments.contains(flatComment.comment.id),
                            onCollapseToggle: {
                                if collapsedComments.contains(flatComment.comment.id) {
                                    collapsedComments.remove(flatComment.comment.id)
                                } else {
                                    collapsedComments.insert(flatComment.comment.id)
                                }
                            }
                        )
                        .padding(.leading, CGFloat(flatComment.depth * 24))
                        .padding(.horizontal, flatComment.depth == 0 ? 0 : 8)
                        .padding(.vertical, 4)
                        .modifier(RootCommentWidthModifier(isRootComment: flatComment.depth == 0))
                    }
                    
                case .loadMore(let flatMoreComments):
                    if shouldShowLoadMore(flatMoreComments) {
                        LoadMoreCommentsView(
                            moreComments: flatMoreComments.moreComments,
                            post: post,
                            sort: sort,
                            isLoading: loadingMoreIds.contains(flatMoreComments.id),
                            onStartLoad: {
                                loadingMoreIds.insert(flatMoreComments.id)
                            },
                            onLoadMore: { newComments in
                                loadingMoreIds.remove(flatMoreComments.id)
                                injectCommentsIntoFlatArray(newComments, replacingMoreId: flatMoreComments.id)
                            },
                            onError: {
                                loadingMoreIds.remove(flatMoreComments.id)
                            },
                            depthColor: depthColor(for: flatMoreComments.depth)
                        )
                        .padding(.leading, CGFloat(flatMoreComments.depth * 24))
                        .padding(.horizontal, flatMoreComments.depth == 0 ? 0 : 8)
                        .padding(.vertical, 4)
                        .modifier(RootCommentWidthModifier(isRootComment: flatMoreComments.depth == 0))
                    }
                }
            }
        }
        .onChange(of: comments) { oldComments, newComments in
            guard oldComments.count != newComments.count else { return }
            let rebuilt = Self.flattenAllComments(comments: newComments)
                flatItems = rebuilt
                    }
    }
    
    // MARK: - Flat Array Management
    
    private static func flattenAllComments(comments: [RedditComment]) -> [FlatCommentItem] {
        var items: [FlatCommentItem] = []
        // Flatten all comment trees (including nested MoreComments)
        for comment in comments {
            items.append(contentsOf: flattenCommentTree(comment: comment))
        }
        return items
    }
    
    private static func flattenCommentTree(comment: RedditComment) -> [FlatCommentItem] {
        var items: [FlatCommentItem] = []
        
        // Add the current comment
        let flatComment = FlatComment(
            id: comment.id,
            comment: comment,
            depth: comment.depth,
            parentId: comment.parentId
        )
        items.append(.comment(flatComment))
        
        // Recursively add replies
        if let replies = comment.replies {
            switch replies {
            case .listing(let commentResponse):
                for child in commentResponse.data.children {
                    switch child.data {
                    case .comment(let nestedComment):
                        items.append(contentsOf: flattenCommentTree(comment: nestedComment))
                    case .more(let moreComments):
                        let flatMore = FlatMoreComments(
                            id: moreComments.id,
                            moreComments: moreComments,
                            depth: moreComments.depth,
                            parentId: moreComments.parentId
                        )
                        items.append(.loadMore(flatMore))
                    }
                }
            case .empty:
                break
            }
        }
        
        return items
    }
    
    private func injectCommentsIntoFlatArray(_ newComments: [RedditComment], replacingMoreId: String) {
        
        guard let moreIndex = flatItems.firstIndex(where: { item in
            if case .loadMore(let flatMore) = item, flatMore.id == replacingMoreId {
                return true
            }
            return false
        }) else {
            return
        }
        
        // Get the MoreComments item being replaced
        let moreItem = flatItems[moreIndex]
        let isRootLevel = moreItem.depth == 0
        
        // Convert new comments to flat items using the complete tree structure
        var newFlatItems: [FlatCommentItem] = []
        
        if isRootLevel {
            // For root-level, flatten each comment tree completely
            for comment in newComments {
                newFlatItems.append(contentsOf: Self.flattenCommentTree(comment: comment))
            }
        } else {
            // For nested comments, just add as flat comments
            for comment in newComments {
                let flatComment = FlatComment(
                    id: comment.id,
                    comment: comment,
                    depth: comment.depth,
                    parentId: comment.parentId
                )
                newFlatItems.append(.comment(flatComment))
            }
        }
        
        // Replace Load More with new comments
        withAnimation(.easeInOut(duration: 0.3)) {
            flatItems.remove(at: moreIndex)
            flatItems.insert(contentsOf: newFlatItems, at: moreIndex)
        }
    }
    
    // MARK: - Collapse Logic
    
    private func shouldShowComment(_ flatComment: FlatComment) -> Bool {
        // Always show root comments
        if flatComment.depth == 0 {
            return true
        }
        
        // Check if any parent comment is collapsed
        return !hasCollapsedParent(commentId: flatComment.comment.id, depth: flatComment.depth)
    }
    
    private func shouldShowLoadMore(_ flatMoreComments: FlatMoreComments) -> Bool {
        let more = flatMoreComments.moreComments
        
        if more.children.isEmpty && more.count == 0 {
            return false
        }
        if more.name == "t1__" || more.rawId == "_" {
            return false
        }
        if flatMoreComments.depth == 0 {
            return true
        }
        
        return !hasCollapsedParentForMore(moreComments: flatMoreComments)
    }
    
    private func hasCollapsedParent(commentId: String, depth: Int) -> Bool {
        guard depth > 0 else { return false }
        
        // Find the parent comment by looking for the comment at depth-1 that comes before this one
        let currentIndex = flatItems.firstIndex { item in
            if case .comment(let flatComment) = item, flatComment.comment.id == commentId {
                return true
            }
            return false
        }
        
        guard let currentIndex = currentIndex else { return false }
        
        // Look backwards for parent at depth-1
        for i in (0..<currentIndex).reversed() {
            if case .comment(let flatComment) = flatItems[i], flatComment.depth == depth - 1 {
                if collapsedComments.contains(flatComment.comment.id) {
                    return true
                }
                // Continue checking parents recursively
                return hasCollapsedParent(commentId: flatComment.comment.id, depth: flatComment.depth)
            }
        }
        
        return false
    }
    
    private func hasCollapsedParentForMore(moreComments: FlatMoreComments) -> Bool {
        guard moreComments.depth > 0 else { return false }
        
        let currentIndex = flatItems.firstIndex { item in
            if case .loadMore(let flatMore) = item, flatMore.id == moreComments.id {
                return true
            }
            return false
        }
        
        guard let currentIndex = currentIndex else { return false }
        
        // Look backwards for parent at depth-1
        for i in (0..<currentIndex).reversed() {
            if case .comment(let flatComment) = flatItems[i], flatComment.depth == moreComments.depth - 1 {
                if collapsedComments.contains(flatComment.comment.id) {
                    return true
                }
                return hasCollapsedParent(commentId: flatComment.comment.id, depth: flatComment.depth)
            }
        }
        
        return false
    }
    
    // MARK: - Helper Functions
    
    private func depthColor(for depth: Int) -> Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if depth == 0 {
            return .clear
        }
        let colorIndex = (depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
    }
}

// MARK: - Supporting Types

enum FlatCommentItem: Identifiable {
    case comment(FlatComment)
    case loadMore(FlatMoreComments)
    
    var id: String {
        switch self {
        case .comment(let flatComment):
            return flatComment.id
        case .loadMore(let flatMoreComments):
            return flatMoreComments.id
        }
    }
    
    var depth: Int {
        switch self {
        case .comment(let flatComment):
            return flatComment.depth
        case .loadMore(let flatMoreComments):
            return flatMoreComments.depth
        }
    }
}

struct FlatComment: Identifiable {
    let id: String
    let comment: RedditComment
    let depth: Int
    let parentId: String?
    var isExpanded: Bool = true
}

struct FlatMoreComments: Identifiable {
    let id: String
    let moreComments: MoreComments
    let depth: Int
    let parentId: String?
}

// Custom modifier to apply post card width to root comments only
struct RootCommentWidthModifier: ViewModifier {
    let isRootComment: Bool
    
    func body(content: Content) -> some View {
        if isRootComment {
            content
                .containerRelativeFrame(.horizontal) { width, _ in
                    width - 32
                    }
        } else {
            content
        }
    }
}
