//
//  CompactCommentView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI
import Defaults

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
    // Appearance (Compact)
    @Default(.commentCompactShowAuthor) private var commentShowAuthor
    @Default(.commentCompactShowAvatar) private var commentShowAvatar
    @Default(.commentCompactShowTime) private var commentShowTime
    @Default(.commentCompactShowScore) private var commentShowScore
    @Default(.commentCompactShowVoteButtons) private var commentShowVoteButtons
    @Default(.commentCompactShowActions) private var commentShowActions
    @Default(.commentCompactUseCardStyle) private var commentUseCardStyle
    // Right-side swipe actions (compact comments)
    @Default(.commentRightSwipeAction1) private var commentRightAction1
    @Default(.commentRightSwipeAction2) private var commentRightAction2
    @Default(.commentRightSwipeAction3) private var commentRightAction3
    @Default(.commentRightSwipeAction4) private var commentRightAction4

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
        Group {
            if commentUseCardStyle {
                Card(style: resolvedCardStyle, highlightColor: highlightColor) {
                    commentLayout
                }
            } else {
                VStack(spacing: 0) {
                    Divider()
                    HStack(alignment: .top, spacing: 0) {
                        if let accentColor, resolvedCardStyle.accentWidth > 0 {
                            Rectangle()
                                .fill(accentColor)
                                .frame(width: resolvedCardStyle.accentWidth)
                        }

                        commentLayout
                            .padding(nonCardContentInsets)
                            .background(alignment: .leading) { nonCardBackground }
                    }
                    Divider()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onCollapseToggle()
            }
        }
        .customSwipeGesture(
            right1: commentRightAction1 != .none ? SwipeAction(
                type: commentRightAction1,
                action: { await handleSwipeAction(commentRightAction1) }
            ) : nil,
            right2: commentRightAction2 != .none ? SwipeAction(
                type: commentRightAction2,
                action: { await handleSwipeAction(commentRightAction2) }
            ) : nil,
            right3: commentRightAction3 != .none ? SwipeAction(
                type: commentRightAction3,
                action: { await handleSwipeAction(commentRightAction3) }
            ) : nil,
            right4: commentRightAction4 != .none ? SwipeAction(
                type: commentRightAction4,
                action: { await handleSwipeAction(commentRightAction4) }
            ) : nil
        )
        .sheet(isPresented: $showingReply) {
            MarkdownComposerView(
                title: "Reply",
                accounts: redditAPI.availableAccountUsernames(),
                activeAccount: redditAPI.userInfo?.name ?? redditAPI.activeUsername,
                onCancel: { showingReply = false },
                onSubmit: { text, account in
                    try await postReply(text: text, account: account)
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

    @ViewBuilder
    private var commentLayout: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCollapsed && commentShowVoteButtons {
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

            VStack(alignment: .leading, spacing: 4) {
                headerRow

                if !isCollapsed {
                    bodyContent
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 6) {
            if commentShowAuthor {
                HStack(spacing: 4) {
                    if commentShowAvatar { UserAvatar(username: comment.author, size: 16) }

                    Text(isDeletedUser ? "[deleted]" : comment.author)
                        .appFont(.caption, weight: .medium)
                        .foregroundStyle(authorColor)
                        .lineLimit(1)

                    if comment.isSubmitter {
                        Text("OP")
                            .appFont(.small, weight: .bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.blue, in: Capsule())
                    }
                }
                Text("•").appFont(.small).foregroundStyle(.tertiary)
            }

            if commentShowTime {
                Text(comment.timeAgo)
                    .appFont(.small)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("•").appFont(.small).foregroundStyle(.tertiary)
            }

            if commentShowScore && !comment.scoreHidden {
                Text(scoreText)
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(scoreColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer()

            if !isCollapsed && commentShowActions {
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
    }

    @ViewBuilder
    private var bodyContent: some View {
        if wasDeleted || comment.body == "[deleted]" || comment.body == "[removed]" {
            Text("[deleted]")
                .appFont(.caption)
                .italic()
                .foregroundStyle(.tertiary)
        } else {
            MarkdownRenderer(content: comment.body, compactMode: false)
                .appFont(.caption)
                .foregroundStyle(.primary)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resolvedCardStyle: CardStyle {
        CardStyle.comment(depth: depth, accentColor: accentColor)
            .withCornerRadius(nonCardCornerRadius)
    }

    private var accentColor: Color? {
        if comment.isSubmitter {
            return .accentColor
        } else if depth > 0 {
            return depthColor
        }
        return nil
    }

    private var highlightColor: Color? {
        comment.stickied ? Color.green.opacity(0.10) : nil
    }

    private var nonCardCornerRadius: CGFloat {
        CGFloat(depth == 0 ? Defaults[.commentRootCardCornerRadius] : Defaults[.commentChildCardCornerRadius])
    }

    private var nonCardContentInsets: EdgeInsets {
        EdgeInsets(
            top: resolvedCardStyle.padding.top,
            leading: 0,
            bottom: resolvedCardStyle.padding.bottom,
            trailing: 0
        )
    }

    @ViewBuilder
    private var nonCardBackground: some View {
        if commentUseCardStyle, let highlightColor {
            RoundedRectangle(cornerRadius: nonCardCornerRadius, style: .continuous)
                .fill(highlightColor)
        }
    }


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

    private func postReply(text: String, account: String) async throws {
        let parent = "t1_\(comment.id)"
        let created = try await redditAPI.performUsingAccount(username: account) {
            try await redditAPI.submitComment(parentFullname: parent, text: text)
        }
        await MainActor.run {
            onReplyPosted(created)
        }
    }

    private func handleSwipeAction(_ actionType: SwipeActionType) async {
        await MainActor.run {
            switch actionType {
            case .upvote:
                handleVote(.upvoted)
            case .downvote:
                handleVote(.downvoted)
            case .save:
                handleSave()
            case .share:
                if let url = URL(string: "https://www.reddit.com\(comment.permalink)") {
                    UIPasteboard.general.url = url
                }
            case .reply:
                showingReply = true
            case .profile:
                if !isDeletedUser {
                    navigationPath.navigate(to: .userProfile(username: comment.author))
                }
            case .parentComment:
                // In compact thread view, parent scroll is handled by container if provided
                // Here we just collapse/expand as a hint
                onCollapseToggle()
            case .collapse:
                onCollapseToggle()
            case .collapseToTop:
                onCollapseToggle()
            case .subreddit, .hide, .hideAbove, .copyLink, .none:
                break
            }
        }
    }
}
