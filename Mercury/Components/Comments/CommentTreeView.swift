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
    @State private var localComment: RedditComment
    @State private var expandedMoreIds: Set<String> = []
    @State private var loadedComments: [String: [RedditComment]] = [:]
    @State private var loadingMoreIds: Set<String> = []
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(comment: RedditComment, post: RedditPost, isRootComment: Bool) {
        self.comment = comment
        self.post = post
        self.isRootComment = isRootComment
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
        self._localComment = State(initialValue: comment)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main comment
            commentContent
            
            // Nested replies with proper Apple-style threading
            if !isCollapsed, let replies = localComment.replies {
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
                            
                            // Load more comments - show loaded comments or "more" buttons
                            ForEach(moreComments, id: \.id) { moreComment in
                                if expandedMoreIds.contains(moreComment.id) {
                                    // Show loaded comments instead of "more" button
                                    ForEach(loadedComments[moreComment.id] ?? [], id: \.id) { loadedComment in
                                        CommentTreeView(
                                            comment: loadedComment,
                                            post: post,
                                            isRootComment: false
                                        )
                                    }
                                } else {
                                    LoadMoreCommentsView(
                                        moreComments: moreComment,
                                        post: post,
                                        isLoading: loadingMoreIds.contains(moreComment.id),
                                        onStartLoad: {
                                            print("🔄 CommentTreeView: Setting loading state for more ID: \(moreComment.id)")
                                            loadingMoreIds.insert(moreComment.id)
                                        },
                                        onLoadMore: { newComments in
                                            Task {
                                                await handleLoadMoreComments(newComments, replacingMoreId: moreComment.id)
                                            }
                                        },
                                        onError: {
                                            loadingMoreIds.remove(moreComment.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                case .empty:
                    // No replies
                    EmptyView()
                }
            }
        }
    }
    
    private var commentContent: some View {
        Card(style: .comment(depth: comment.depth, accentColor: comment.depth > 0 ? depthColor : nil)) {
            HStack(alignment: .top, spacing: 12) {
                // Profile picture - consistent with post design
                UserAvatar(username: comment.author, size: 32)
                    .onTapGesture {
                        navigationPath.navigate(to: .userProfile(username: comment.author))
                    }
                
                // Comment content - matches post content layout
                VStack(alignment: .leading, spacing: 8) {
                    commentHeader
                    
                    if !isCollapsed {
                        commentBody
                        commentActions
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, CGFloat(comment.depth * 16)) // Clean indentation
        .padding(.horizontal, comment.depth == 0 ? 12 : 8)
        .padding(.vertical, 4)
    }
    
    private var commentHeader: some View {
        HStack(spacing: 8) {
            // Author and badges - matches post header style
            HStack(spacing: 6) {
                Text(comment.author)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(authorColor)
                
                if comment.isSubmitter {
                    Pill(size: .small) {
                        Text("OP")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .background(.blue, in: Capsule())
                }
                
                if let distinguished = comment.distinguished {
                    Pill(size: .small) {
                        Text(distinguished.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .background(.green, in: Capsule())
                }
            }
            
            Spacer()
            
            // Meta info - clean and minimal
            HStack(spacing: 4) {
                if !comment.scoreHidden {
                    Text(scoreText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                }
                
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                
                Text(comment.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Collapse button - minimal and clean
                if hasReplies {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                    Image(systemName: voteState == .upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.callout)
                        .foregroundStyle(voteState == .upvoted ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
                
                Button {
                    handleVote(.downvoted)
                } label: {
                    Image(systemName: voteState == .downvoted ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.callout)
                        .foregroundStyle(voteState == .downvoted ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
            }
            
            // Action buttons - minimal
            Button(action: {
                // TODO: Implement reply functionality
            }) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .labelStyle(.iconOnly)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                handleSave()
            }) {
                Label(comment.saved ? "Saved" : "Save", 
                      systemImage: comment.saved ? "bookmark.fill" : "bookmark")
                    .labelStyle(.iconOnly)
                    .font(.callout)
                    .foregroundStyle(comment.saved ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Properties
    
    private var depthColor: Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if comment.depth == 0 {
            return .clear
        }
        let colorIndex = (comment.depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
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
    
    @MainActor
    private func handleLoadMoreComments(_ newComments: [RedditComment], replacingMoreId: String) async {
        print("🔄 CommentTreeView: handleLoadMoreComments called with \(newComments.count) comments for more ID: \(replacingMoreId)")
        
        // Store loaded comments in state dictionary first
        loadedComments[replacingMoreId] = newComments
        print("🔄 CommentTreeView: Stored \(newComments.count) comments in loadedComments[\(replacingMoreId)]")
        
        // Remove from loading state
        loadingMoreIds.remove(replacingMoreId)
        print("🔄 CommentTreeView: Removed \(replacingMoreId) from loadingMoreIds. Current loading: \(loadingMoreIds)")
        
        // Mark as expanded (no animation)
        expandedMoreIds.insert(replacingMoreId)
        print("🔄 CommentTreeView: Added \(replacingMoreId) to expandedMoreIds. Current expanded: \(expandedMoreIds)")
        
        print("✅ CommentTreeView: Comments successfully injected into view for more ID: \(replacingMoreId)")
    }
}

