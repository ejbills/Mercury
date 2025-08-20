//
//  CompactCommentView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct CompactCommentView: View {
    let comment: RedditComment
    let depth: Int
    let post: RedditPost
    let isCollapsed: Bool
    let onCollapseToggle: () -> Void
    let onReplyPosted: (RedditComment) -> Void
    
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    @State private var showingReply = false
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var wasDeleted = false

    init(comment: RedditComment, depth: Int, post: RedditPost, isCollapsed: Bool = false, onCollapseToggle: @escaping () -> Void = {}, onReplyPosted: @escaping (RedditComment) -> Void = { _ in }) {
        self.comment = comment
        self.depth = depth
        self.post = post
        self.isCollapsed = isCollapsed
        self.onCollapseToggle = onCollapseToggle
        self.onReplyPosted = onReplyPosted
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
    }
    
    var body: some View {
        Card(
            style: .comment(depth: depth, accentColor: (comment.isSubmitter ? Color.accentColor : (depth > 0 ? depthColor : nil))),
            highlightColor: comment.stickied ? Color.green.opacity(0.10) : nil
        ) {
            HStack(alignment: .top, spacing: 8) {
                // Compact vote controls on the left (hidden when collapsed)
                if !isCollapsed {
                    VStack(spacing: 2) {
                        VoteButton(
                            direction: .up,
                            isActive: voteState == .upvoted,
                            size: .small,
                            colorScheme: .light,
                            disabled: isVoting || !comment.canVote
                        ) {
                            handleVote(.upvoted)
                        }
                        
                        // Score moved to header toolbar in compact mode
                        
                        VoteButton(
                            direction: .down,
                            isActive: voteState == .downvoted,
                            size: .small,
                            colorScheme: .light,
                            disabled: isVoting || !comment.canVote
                        ) {
                            handleVote(.downvoted)
                        }
                    }
                    .frame(width: 32)
                }
                
                // Main content area
                VStack(alignment: .leading, spacing: 4) {
                    // Compact header - single line with author and meta
                    HStack(spacing: 6) {
                        // Author with badges
                        HStack(spacing: 4) {
                            UserAvatar(username: comment.author, size: 16, disableAPIFetch: true)
                            
                            Text(isDeletedUser ? "[deleted]" : comment.author)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(authorColor)
                                .lineLimit(1)
                            
                            if comment.isSubmitter {
                                Text("OP")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(.blue, in: Capsule())
                            }
                        }
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        Text(comment.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if !comment.scoreHidden {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(scoreText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(scoreColor)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        
                        Spacer()

                        // Inline actions in header
                        if !isCollapsed {
                            Button(action: { showingReply = true }) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button(action: { handleSave() }) {
                                    Label(comment.saved ? "Unsave" : "Save",
                                          systemImage: comment.saved ? "bookmark.fill" : "bookmark")
                                }
                                if canDeleteComment {
                                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        // Collapse button
                        Button(action: {
                            withAnimation(.snappy(duration: 0.125)) {
                                onCollapseToggle()
                            }
                        }) {
                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Comment body - compact mode
                    if !isCollapsed {
                        Group {
                            if wasDeleted || comment.body == "[deleted]" || comment.body == "[removed]" {
                                Text("[deleted]")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.tertiary)
                            } else {
                                MarkdownRenderer(content: comment.body, compactMode: true)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineSpacing(1)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        // Actions moved inline with header in compact mode
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onCollapseToggle()
            }
        }
        .sheet(isPresented: $showingReply) {
            MarkdownComposerView(
                title: "Reply",
                onCancel: { showingReply = false },
                onSubmit: { text in
                    try await postReply(text: text)
                }
            )
        }
        .alert("Delete Comment?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteComment() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }
    
    // MARK: - Helper Properties
    
    private var depthColor: Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if depth == 0 {
            return .clear
        }
        let colorIndex = (depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
    }
    
    private var authorColor: Color {
        if isDeletedUser {
            return .secondary
        } else if comment.isSubmitter {
            return .accentColor
        } else if comment.distinguished != nil {
            return .green
        } else {
            return .primary
        }
    }
    
    private var isDeletedUser: Bool {
        return wasDeleted || comment.author == "[deleted]" || comment.author == "deleted"
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
                    voteState = originalState
                    displayScore = originalScore
                    isVoting = false
                }
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

    private var canDeleteComment: Bool {
        if let me = redditAPI.userInfo?.name {
            return me.caseInsensitiveCompare(comment.author) == .orderedSame
        }
        return false
    }

    @MainActor
    private func deleteComment() async {
        guard !isDeleting else { return }
        isDeleting = true
        do {
            try await redditAPI.deleteComment(commentId: comment.id)
            wasDeleted = true
            isDeleting = false
        } catch {
            isDeleting = false
            print("Failed to delete comment: \(error)")
        }
    }

    private func postReply(text: String) async throws {
        let parent = "t1_\(comment.id)"
        let created = try await redditAPI.submitComment(parentFullname: parent, text: text)
        await MainActor.run {
            onReplyPosted(created)
        }
    }
}
