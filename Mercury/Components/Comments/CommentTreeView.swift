//
//  CommentTreeView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct CommentTreeView: View {
    let comment: RedditComment
    let post: RedditPost
    let isRootComment: Bool
    
    @State private var isCollapsed = false
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    
    // New flat state management - mixed array of comments and Load More buttons
    @State private var flatItems: [FlatCommentItem] = []
    @State private var loadingMoreIds: Set<String> = []
    
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    // Unified structure for comments and Load More buttons
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
    
    // Flat comment structure for easier state management
    struct FlatComment: Identifiable {
        let id: String
        let comment: RedditComment
        let depth: Int
        let parentId: String?
        var isExpanded: Bool = true
    }
    
    // MoreComments representation in flat structure
    struct FlatMoreComments: Identifiable {
        let id: String
        let moreComments: MoreComments
        let depth: Int
        let parentId: String?
    }
    
    init(comment: RedditComment, post: RedditPost, isRootComment: Bool) {
        self.comment = comment
        self.post = post
        self.isRootComment = isRootComment
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
        
        // Initialize flat structure from nested comment tree
        let initialFlatItems = Self.flattenCommentTree(comment: comment)
        self._flatItems = State(initialValue: initialFlatItems)
    }
    
    // Convert nested comment tree to flat array
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
        } else {
        }
        
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main comment content
            mainCommentContent
            
            // Only render nested structure if this is the main comment view
            // For nested comments, use the traditional nested rendering
            if !isCollapsed && comment.replies != nil {
                if isRootComment {
                    // Root comment: use flat array for entire thread
                    renderFlatCommentThread()
                } else {
                    // Nested comment: use traditional nested rendering
                    renderNestedReplies()
                }
            } else {
            }
        }
    }
    
    private func renderFlatCommentThread() -> some View {
        LazyVStack(spacing: 0) {
            // Skip the first item (which is this comment itself) and render the rest
            ForEach(Array(flatItems.dropFirst().enumerated()), id: \.element.id) { index, item in
                
                switch item {
                case .comment(let flatComment):
                    let shouldShow = shouldShowComment(flatComment)
                    
                    if shouldShow {
                        commentView(for: flatComment)
                            .padding(.leading, CGFloat(flatComment.depth * 24))
                            .padding(.horizontal, flatComment.depth == 0 ? 0 : 8)
                            .padding(.vertical, 4)
                    }
                case .loadMore(let flatMoreComments):
                    let shouldShow = shouldShowLoadMore(flatMoreComments)
                    
                    if shouldShow {
                        LoadMoreCommentsView(
                            moreComments: flatMoreComments.moreComments,
                            post: post,
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
                            }
                        )
                    }
                }
            }
        }
    }
    
    private func renderNestedReplies() -> some View {
        // Traditional nested rendering for non-root comments
        Group {
            if let replies = comment.replies {
                switch replies {
                case .listing(let commentResponse):
                    let nestedComments = commentResponse.flattenedComments
                    let moreComments = commentResponse.moreComments
                    
                    if !nestedComments.isEmpty || !moreComments.isEmpty {
                        LazyVStack(spacing: 0) {
                            // Nested comments
                            ForEach(nestedComments, id: \.id) { nestedComment in
                                CommentTreeView(
                                    comment: nestedComment,
                                    post: post,
                                    isRootComment: false
                                )
                            }
                            
                            // Load more comments
                            ForEach(moreComments, id: \.id) { moreComment in
                                LoadMoreCommentsView(
                                    moreComments: moreComment,
                                    post: post,
                                    isLoading: loadingMoreIds.contains(moreComment.id),
                                    onStartLoad: {
                                        loadingMoreIds.insert(moreComment.id)
                                    },
                                    onLoadMore: { newComments in
                                        loadingMoreIds.remove(moreComment.id)
                                        // For nested comments, we'll need to handle this differently
                                        // For now, fall back to traditional injection
                                        print("⚠️ Load More in nested comment - needs traditional handling")
                                    },
                                    onError: {
                                        loadingMoreIds.remove(moreComment.id)
                                    }
                                )
                            }
                        }
                    }
                case .empty:
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // Helper methods for flat array rendering
    private func shouldShowComment(_ flatComment: FlatComment) -> Bool {
        // Root comments always show
        if flatComment.depth == comment.depth {
            return true
        }
        
        // Check if all parent comments are expanded
        return isParentExpanded(parentId: flatComment.parentId, targetDepth: flatComment.depth - 1)
    }
    
    private func shouldShowLoadMore(_ flatMoreComments: FlatMoreComments) -> Bool {
        // Check if parent comment is expanded
        return isParentExpanded(parentId: flatMoreComments.parentId, targetDepth: flatMoreComments.depth - 1)
    }
    
    private func isParentExpanded(parentId: String?, targetDepth: Int) -> Bool {
        guard let parentId = parentId else { return true }
        
        // Find parent comment in flat array
        for item in flatItems {
            if case .comment(let flatComment) = item,
               flatComment.id == parentId.replacingOccurrences(of: "t1_", with: "") {
                return flatComment.isExpanded && isParentExpanded(parentId: flatComment.parentId, targetDepth: targetDepth - 1)
            }
        }
        
        return true
    }
    
    private func commentView(for flatComment: FlatComment) -> some View {
        Card(style: .comment(depth: flatComment.depth, accentColor: flatComment.depth > 0 ? depthColor(for: flatComment.depth) : nil)) {
            VStack(alignment: .leading, spacing: 8) {
                commentHeaderView(for: flatComment.comment)
                commentBodyView(for: flatComment.comment)
                commentActionsView(for: flatComment.comment)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(RootCommentWidthModifier(isRootComment: flatComment.depth == 0))
    }
    
    private func commentBodyView(for commentData: RedditComment) -> some View {
        Group {
            if commentData.body == "[deleted]" || commentData.body == "[removed]" {
                Text(commentData.body)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.tertiary)
            } else {
                Text(commentData.body)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func commentActionsView(for commentData: RedditComment) -> some View {
        HStack(spacing: 16) {
            // Vote controls - compact and clean like post voting
            HStack(spacing: 8) {
                Button {
                    // Handle vote for this specific comment
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button {
                    // Handle vote for this specific comment
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Action menu
            Menu {
                Button(action: {
                    // TODO: Implement reply functionality
                }) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                
                Button(action: {
                    // TODO: Handle save for this specific comment
                }) {
                    Label(commentData.saved ? "Unsave" : "Save", 
                          systemImage: commentData.saved ? "bookmark.fill" : "bookmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var mainCommentContent: some View {
        Card(style: .comment(depth: comment.depth, accentColor: comment.depth > 0 ? depthColor : nil)) {
            VStack(alignment: .leading, spacing: 8) {
                commentHeader
                
                if !isCollapsed {
                    commentBody
                    commentActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        .padding(.leading, CGFloat(comment.depth * 24)) // Clean indentation
        .padding(.horizontal, comment.depth == 0 ? 0 : 8) // No horizontal padding for root comments
        .padding(.vertical, 4)
        .modifier(RootCommentWidthModifier(isRootComment: comment.depth == 0))
    }
    
    // Custom modifier to apply post card width to root comments only
    struct RootCommentWidthModifier: ViewModifier {
        let isRootComment: Bool
        
        func body(content: Content) -> some View {
            if isRootComment {
                content
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width - 32 // 16pt margin on each side, same as PostRowView
                    }
            } else {
                content
            }
        }
    }
    
    private var commentHeader: some View {
        HStack(spacing: 8) {
            // Author section with profile picture and pill
            HStack(spacing: 6) {
                // Small profile picture
                UserAvatar(username: comment.author, size: 20)
                
                // Author pill with badges - matches post design pattern
                Pill(action: {
                    navigationPath.navigate(to: .userProfile(username: comment.author))
                }, size: .small) {
                    HStack(spacing: 4) {
                        Text(comment.author)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(authorColor)
                            .lineLimit(1)
                        
                        if comment.isSubmitter {
                            Text("OP")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue, in: Capsule())
                        }
                        
                        if let distinguished = comment.distinguished {
                            Text(distinguished.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.green, in: Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Meta info pills - clean and minimal
            HStack(spacing: 4) {
                if !comment.scoreHidden {
                    Pill(size: .small) {
                        Text(scoreText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()
                    }
                }
                
                Pill(size: .small) {
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Pill(action: {
                    withAnimation(.snappy(duration: 0.125)) {
                        isCollapsed.toggle()
                    }
                }, size: .small) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var commentBody: some View {
        Group {
            if comment.body == "[deleted]" || comment.body == "[removed]" {
                deletedCommentView
            } else {
                Text(comment.body)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var deletedCommentView: some View {
        Text(comment.body)
            .font(.subheadline)
            .italic()
            .foregroundStyle(.tertiary)
    }
    
    private var commentActions: some View {
        HStack(spacing: 16) {
            // Vote controls - compact and clean like post voting
            HStack(spacing: 8) {
                Button {
                    handleVote(.upvoted)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.callout)
                        .foregroundStyle(voteState == .upvoted ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
                
                Button {
                    handleVote(.downvoted)
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.callout)
                        .foregroundStyle(voteState == .downvoted ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
            }
            
            // Action menu
            Menu {
                Button(action: {
                    // TODO: Implement reply functionality
                }) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                
                Button(action: {
                    handleSave()
                }) {
                    Label(comment.saved ? "Unsave" : "Save", 
                          systemImage: comment.saved ? "bookmark.fill" : "bookmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Properties
    
    private func depthColor(for depth: Int) -> Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if depth == 0 {
            return .clear
        }
        let colorIndex = (depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
    }
    
    private var depthColor: Color {
        return depthColor(for: comment.depth)
    }
    
    private func commentHeaderView(for commentData: RedditComment) -> some View {
        HStack(spacing: 8) {
            // Author section with profile picture and pill
            HStack(spacing: 6) {
                // Small profile picture
                UserAvatar(username: commentData.author, size: 20)
                
                // Author pill with badges - matches post design pattern
                Pill(action: {
                    navigationPath.navigate(to: .userProfile(username: commentData.author))
                }, size: .small) {
                    HStack(spacing: 4) {
                        Text(commentData.author)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(authorColorFor(commentData))
                            .lineLimit(1)
                        
                        if commentData.isSubmitter {
                            Text("OP")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue, in: Capsule())
                        }
                        
                        if let distinguished = commentData.distinguished {
                            Text(distinguished.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.green, in: Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Meta info pills - clean and minimal
            HStack(spacing: 4) {
                if !commentData.scoreHidden {
                    Pill(size: .small) {
                        Text(scoreTextFor(commentData))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                }
                
                Pill(size: .small) {
                    Text(commentData.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Collapse indicator - visual only  
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20) // Fixed size to prevent shifting
            }
        }
    }
    
    private func authorColorFor(_ commentData: RedditComment) -> Color {
        if commentData.isSubmitter {
            return .blue
        } else if commentData.distinguished != nil {
            return .green
        } else {
            return .primary
        }
    }
    
    private func scoreTextFor(_ commentData: RedditComment) -> String {
        if commentData.scoreHidden {
            return "•"
        }
        
        let score = max(0, commentData.displayScore)
        if score >= 1000 {
            let kScore = Double(score) / 1000.0
            return String(format: "%.1fk", kScore)
        } else {
            return String(score)
        }
    }
    
    private var authorColor: Color {
        if comment.isSubmitter {
            return .blue
        } else if comment.distinguished != nil {
            return .green
        } else {
            return .primary
        }
    }
    
    private var scoreText: String {
        if comment.scoreHidden {
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
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted: return .orange
        case .downvoted: return .blue
        case .neutral: return .primary
        }
    }
    
    private var hasReplies: Bool {
        guard let replies = comment.replies else { return false }
        return !replies.comments.isEmpty
    }
    
    // MARK: - Flat Array Comment Injection
    
    private func injectCommentsIntoFlatArray(_ newComments: [RedditComment], replacingMoreId: String) {
        
        // Find the index of the Load More button to replace
        guard let moreIndex = flatItems.firstIndex(where: { item in
            if case .loadMore(let flatMore) = item, flatMore.id == replacingMoreId {
                return true
            }
            return false
        }) else {
            return
        }
        
        // Get the Load More button's parent info for proper insertion
        let moreItem = flatItems[moreIndex]
        let parentDepth = moreItem.depth - 1
        let parentId: String?
        
        if case .loadMore(let flatMore) = moreItem {
            parentId = flatMore.parentId
        } else {
            parentId = nil
        }
        
        // Convert new comments to flat items with proper parent relationships
        var newFlatItems: [FlatCommentItem] = []
        
        for comment in newComments {
            
            // Set proper parent ID if missing
            var processedComment = comment
            if processedComment.parentId == nil || processedComment.parentId?.isEmpty == true {
                if comment.depth == parentDepth + 1 {
                    processedComment = updateCommentParentId(comment, newParentId: parentId ?? "")
                }
            }
            
            let flatComment = FlatComment(
                id: processedComment.id,
                comment: processedComment,
                depth: processedComment.depth,
                parentId: processedComment.parentId
            )
            newFlatItems.append(.comment(flatComment))
        }
        
        // Remove the Load More button and insert new comments
        withAnimation(.easeInOut(duration: 0.3)) {
            flatItems.remove(at: moreIndex)
            flatItems.insert(contentsOf: newFlatItems, at: moreIndex)
        }
        
    }
    
    // MARK: - Actions
    
    private func handleVote(_ newState: RedditComment.VoteState) {
        guard !isVoting && comment.canVote else { return }
        
        let originalState = voteState
        let originalScore = displayScore
        
        // Optimistic update
        voteState = newState == voteState ? .neutral : newState
        updateDisplayScore(from: originalState, to: voteState)
        
        isVoting = true
        
        Task {
            do {
                let direction: VoteDirection = switch voteState {
                case .upvoted: .upvote
                case .downvoted: .downvote
                case .neutral: .neutral
                }
                
                try await redditAPI.voteOnComment(commentId: comment.id, voteDirection: direction)
                
                await MainActor.run {
                    isVoting = false
                }
            } catch {
                await MainActor.run {
                    // Revert on failure
                    voteState = originalState
                    displayScore = originalScore
                    isVoting = false
                }
                print("Failed to vote on comment: \(error)")
            }
        }
    }
    
    private func updateDisplayScore(from oldState: RedditComment.VoteState, to newState: RedditComment.VoteState) {
        switch (oldState, newState) {
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
        default:
            break
        }
    }
    
    private func handleSave() {
        Task {
            do {
                if comment.saved {
                    try await redditAPI.unsaveComment(commentId: comment.id)
                } else {
                    try await redditAPI.saveComment(commentId: comment.id)
                }
            } catch {
                print("Failed to save/unsave comment: \(error)")
            }
        }
    }
    
    // Old complex tree building logic - replaced by simple flat array approach
    
    private func updateCommentParentId(_ comment: RedditComment, newParentId: String) -> RedditComment {
        // Since RedditComment doesn't have a memberwise initializer, we need to use a different approach
        // We'll create the comment through JSON encoding/decoding with the updated parent ID
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(comment)
            
            // Decode as dictionary to modify parent_id
            var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            dict["parent_id"] = newParentId
            
            // Re-encode and decode as RedditComment
            let modifiedData = try JSONSerialization.data(withJSONObject: dict)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            var modifiedComment = try decoder.decode(RedditComment.self, from: modifiedData)
            
            // Preserve local state
            modifiedComment.currentVoteState = comment.currentVoteState
            modifiedComment.displayScore = comment.displayScore
            modifiedComment.isCollapsed = comment.isCollapsed
            
            return modifiedComment
        } catch {
            print("⚠️ Failed to update parent ID, returning original comment: \(error)")
            return comment
        }
    }
}

