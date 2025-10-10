//
//  CommentThreadView.swift
//  Mercury
//
//

import SwiftUI
import Defaults

struct CommentThreadView: View {
    let comments: [RedditComment]
    let post: RedditPost
    let sort: CommentSort
    @Binding var scrollTarget: String?

    // Unified flat state management for entire thread
    @State private var flatItems: [FlatCommentItem] = []
    @State private var loadingMoreIds: Set<String> = []
    @State private var collapsedComments: Set<String> = []
    @State private var itemVisibility: [Bool] = []
    @Default(.commentLayoutStyle) private var commentLayoutStyle
    @Default(.commentRowVerticalPadding) private var commentRowVerticalPadding

    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath

    init(comments: [RedditComment], post: RedditPost, sort: CommentSort, scrollTarget: Binding<String?>) {
        self.comments = comments
        self.post = post
        self.sort = sort
        self._scrollTarget = scrollTarget
        
        // Initialize flat structure from all comments
        let initialFlatItems = Self.flattenAllComments(comments: comments)
        self._flatItems = State(initialValue: initialFlatItems)
        // Collapse stickied comments by default (top-level input only contains roots)
        let initialCollapsed = Set(comments.filter { $0.stickied }.map { $0.id })
        self._collapsedComments = State(initialValue: initialCollapsed)
    }
    
    var body: some View {
        // Use VStack instead of LazyVStack to keep comment rows in memory
        // and preserve total content height when items scroll off-screen.
        VStack(spacing: 0) {
            ForEach(Array(flatItems.enumerated()), id: \.element.id) { index, _ in
                row(at: index)
            }
        }
        .onChange(of: topLevelCommentIDs) {
            let rebuilt = Self.flattenAllComments(comments: comments)
            flatItems = rebuilt
            // Ensure newly present stickied comments start collapsed without overwriting user toggles
            let stickyIds = comments.filter { $0.stickied }.map { $0.id }
            collapsedComments.formUnion(stickyIds)
            recomputeVisibility()
        }
        .onAppear {
            recomputeVisibility()
        }
        .onChange(of: flatItemIDs) {
            recomputeVisibility()
        }
        .onChange(of: collapsedComments) {
            recomputeVisibility()
        }
    }

    private var topLevelCommentIDs: [String] { comments.map { $0.id } }
    private var flatItemIDs: [String] { flatItems.map { $0.id } }

    // MARK: - Row Builder
    
    @ViewBuilder
    private func row(at index: Int) -> some View {
        if index >= 0 && index < flatItems.count {
            let item = flatItems[index]
            switch item {
            case .comment(let flatComment):
                if isIndexVisible(index) {
                    Group {
                        if commentLayoutStyle == .compact {
                            CompactCommentView(
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
                                },
                                onReplyPosted: { newComment in
                                    insertReply(newComment, underParentId: flatComment.comment.id, parentDepth: flatComment.depth)
                                }
                            )
                        } else {
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
                        },
                        onCollapseParent: {
                            let rootCommentId = findRootComment(for: flatComment)
                            
                            if let rootCommentId = rootCommentId {
                                _ = withAnimation(.snappy(duration: 0.2)) {
                                    collapsedComments.insert(rootCommentId)
                                }
                            }
                        },
                        onScrollToParent: {
                            let rootCommentId = findRootComment(for: flatComment)

                            if let rootCommentId = rootCommentId {
                                withAnimation(.snappy(duration: 0.3)) {
                                    scrollTarget = rootCommentId
                                }
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    if scrollTarget == rootCommentId {
                                        scrollTarget = nil
                                    }
                                }
                            }
                        },
                        onReplyPosted: { newComment in
                            insertReply(newComment, underParentId: flatComment.comment.id, parentDepth: flatComment.depth)
                        },
                    )
                    
                        }
                    }
                    .id(flatComment.comment.id)
                    .padding(.leading, CGFloat(flatComment.depth * 12))
                    .padding(.vertical, CGFloat(commentRowVerticalPadding))
                } else {
                    EmptyView()
                }
            case .loadMore(let flatMoreComments):
                if isIndexVisible(index) {
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
                    .padding(.leading, CGFloat(flatMoreComments.depth * 12))
                    .padding(.vertical, CGFloat(commentRowVerticalPadding))
                    // Root-level load-more rows also expand naturally. depth=\(flatMoreComments.depth)")
                } else {
                    EmptyView()
                }
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Flat Array Management
    
    private static func flattenAllComments(comments: [RedditComment]) -> [FlatCommentItem] {
        var items: [FlatCommentItem] = []
        // Flatten all comment trees (including nested MoreComments)
        for comment in comments {
            // Top-level comments have no parent (parentId = nil)
            items.append(contentsOf: flattenCommentTree(comment: comment, parentId: nil))
        }
        return items
    }
    
    private static func flattenCommentTree(comment: RedditComment, parentId: String? = nil) -> [FlatCommentItem] {
        var items: [FlatCommentItem] = []
        
        // Add the current comment with the properly set parent ID
        let flatComment = FlatComment(
            id: comment.id,
            comment: comment,
            depth: comment.depth,
            parentId: parentId
        )
        items.append(.comment(flatComment))
        
        // Recursively add replies, setting this comment as their parent
        if let replies = comment.replies {
            switch replies {
            case .listing(let commentResponse):
                for child in commentResponse.data.children {
                    switch child.data {
                    case .comment(let nestedComment):
                        // Set this comment's ID as the parent for its replies
                        items.append(contentsOf: flattenCommentTree(comment: nestedComment, parentId: comment.id))
                    case .post:
                        // Replies should not include posts; ignore defensively
                        break
                    case .more(let moreComments):
                        let flatMore = FlatMoreComments(
                            id: moreComments.id,
                            moreComments: moreComments,
                            depth: moreComments.depth,
                            parentId: comment.id  // Set this comment as parent for "more" items too
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
            // For root-level, flatten each comment tree completely (no parent)
            for comment in newComments {
                newFlatItems.append(contentsOf: Self.flattenCommentTree(comment: comment, parentId: nil))
            }
        } else {
            // For nested comments, use the parent ID from the "more" item being replaced
            let parentId: String?
            if case .loadMore(let flatMore) = moreItem {
                parentId = flatMore.parentId
            } else {
                parentId = nil
            }
            for comment in newComments {
                newFlatItems.append(contentsOf: Self.flattenCommentTree(comment: comment, parentId: parentId))
            }
        }
        
        withAnimation(.snappy(duration: 0.3)) {
            flatItems.remove(at: moreIndex)
            flatItems.insert(contentsOf: newFlatItems, at: moreIndex)
        }
    }
    
    // MARK: - Collapse Logic
    
    // Fast visibility computation using a single pass and a collapsed-ancestor stack
    private func recomputeVisibility() {
        var visibility = Array(repeating: true, count: flatItems.count)
        var collapsedStack: [Bool] = [] // ancestors only; size == current depth
        var collapsedCount = 0 // true entries in stack (collapsed ancestors)

        for i in 0..<flatItems.count {
            let depth = flatItems[i].depth

            // Ensure stack represents exactly ancestors for this depth
            while collapsedStack.count > depth {
                if let removed = collapsedStack.popLast(), removed { collapsedCount -= 1 }
            }
            while collapsedStack.count < depth {
                collapsedStack.append(false)
            }

            // Determine base visibility for the item itself
            var baseVisible = true
            if case .loadMore(let flatMore) = flatItems[i] {
                let more = flatMore.moreComments
                if (more.children.isEmpty && more.count == 0) || more.name.isEmpty || more.rawId.isEmpty {
                    baseVisible = false
                }
            }

            let hasCollapsedAncestor = collapsedCount > 0
            visibility[i] = baseVisible && !hasCollapsedAncestor

            // After evaluating current item, push current comment's collapse state for descendants
            if case .comment(let flatComment) = flatItems[i] {
                let isCollapsed = collapsedComments.contains(flatComment.comment.id)
                collapsedStack.append(isCollapsed)
                if isCollapsed { collapsedCount += 1 }
            }
        }

        itemVisibility = visibility
    }

    private func isIndexVisible(_ index: Int) -> Bool {
        guard index < itemVisibility.count else { return true }
        return itemVisibility[index]
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

    // MARK: - Insert New Reply

    private func insertReply(_ reply: RedditComment, underParentId parentId: String, parentDepth: Int) {
        guard let parentIndex = flatItems.firstIndex(where: { item in
            if case .comment(let c) = item { return c.comment.id == parentId }
            return false
        }) else {
            return
        }

        let newFlat = FlatComment(
            id: reply.id,
            comment: reply,
            depth: parentDepth + 1,
            parentId: parentId
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            flatItems.insert(.comment(newFlat), at: parentIndex + 1)
        }
    }
}

// MARK: - Ancestor Collapsing
extension CommentThreadView {
    private func collapseAncestors(of commentId: String) {
        // Build parent map from current flatItems
        var parentMap: [String: String] = [:] // childId -> parentId
        for item in flatItems {
            if case .comment(let fc) = item {
                if let parentId = fc.parentId {
                    parentMap[fc.comment.id] = parentId
                }
            }
        }
        var toCollapse: Set<String> = []
        var current: String? = commentId
        while let cid = current {
            toCollapse.insert(cid)
            current = parentMap[cid]
        }
        withAnimation(.snappy(duration: 0.2)) {
            collapsedComments.formUnion(toCollapse)
        }
    }
    
    /// Finds the root (top-level) comment for a given flat comment by traversing up the parent chain
    private func findRootComment(for flatComment: FlatComment) -> String? {
        // If this comment has no parent, it's already the root
        guard flatComment.parentId != nil else {
            return nil // Top-level comments don't have a root to collapse/scroll to
        }
        
        // Build parent map from current flatItems
        var parentMap: [String: String] = [:] // childId -> parentId
        for item in flatItems {
            if case .comment(let fc) = item {
                if let pid = fc.parentId {
                    parentMap[fc.comment.id] = pid
                }
            }
        }
        
        // Traverse up to find the root comment (the one with no parent)
        var current = flatComment.comment.id
        var rootCandidate: String? = nil
        
        while let parent = parentMap[current] {
            rootCandidate = parent
            current = parent
        }
        
        return rootCandidate
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

// Removed custom width modifier; root comments now use container padding.
