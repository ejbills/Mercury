import SwiftUI
import Defaults

struct CommentView: View {
    let comment: RedditComment
    let depth: Int
    let post: RedditPost
    let isCollapsed: Bool
    let onCollapseToggle: () -> Void
    let onReplyPosted: (RedditComment) -> Void
    
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    @Default(.commentLeftShortSwipeAction) private var commentLeftShortSwipeAction
    @Default(.commentLeftLongSwipeAction) private var commentLeftLongSwipeAction
    @Default(.commentRightShortSwipeAction) private var commentRightShortSwipeAction
    @Default(.commentRightLongSwipeAction) private var commentRightLongSwipeAction
    
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
                VStack(alignment: .leading, spacing: 8) {
                    commentHeader
                    
                    if !isCollapsed {
                        commentBody
                        commentActions
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        .customSwipeGesture(
            leftShort: commentLeftShortSwipeAction != .none ? SwipeAction(
                type: commentLeftShortSwipeAction,
                action: { handleSwipeAction(commentLeftShortSwipeAction) }
            ) : nil,
            leftLong: commentLeftLongSwipeAction != .none ? SwipeAction(
                type: commentLeftLongSwipeAction,
                action: { handleSwipeAction(commentLeftLongSwipeAction) }
            ) : nil,
            rightShort: commentRightShortSwipeAction != .none ? SwipeAction(
                type: commentRightShortSwipeAction,
                action: { handleSwipeAction(commentRightShortSwipeAction) }
            ) : nil,
            rightLong: commentRightLongSwipeAction != .none ? SwipeAction(
                type: commentRightLongSwipeAction,
                action: { handleSwipeAction(commentRightLongSwipeAction) }
            ) : nil,
            cornerRadius: depth == 0 ? 16 : 12
        )
    }
    
    private var commentHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                UserAvatar(username: comment.author, size: 20, iconURL: comment.authorIconURL)
                
                Pill(action: {
                    if !isDeletedUser {
                        navigationPath.navigate(to: .userProfile(username: comment.author))
                    }
                }, size: .small) {
                    HStack(spacing: 4) {
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
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue, in: Capsule())
                        }
                        
                    }
                }
            }
            
            Spacer()
            
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
                        onCollapseToggle()
                    }
                }, size: .small) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onCollapseToggle()
            }
        }
    }
    
    private var commentBody: some View {
        Group {
            if wasDeleted || comment.body == "[deleted]" || comment.body == "[removed]" {
                Text("[deleted]")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.tertiary)
            } else {
                MarkdownRenderer(content: comment.body, compactMode: false)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var commentActions: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
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

            Button(action: { showingReply = true }) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
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
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 4)
        .sheet(isPresented: $showingReply) {
            MarkdownComposerView(
                title: "Reply",
                onCancel: { showingReply = false },
                onSubmit: { text in
                    try await postReply(text: text)
                }
            )
        }
        .sheet(isPresented: $showingDeleteConfirm) {
            ConfirmSheet(
                title: "Delete Comment?",
                message: "This cannot be undone.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    Task { await deleteComment() }
                    showingDeleteConfirm = false
                },
                onCancel: {
                    showingDeleteConfirm = false
                }
            )
            .presentationDetents([.fraction(0.25)])
            .presentationDragIndicator(.visible)
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
    
    private func handleSwipeAction(_ actionType: SwipeActionType) {
        switch actionType {
        case .upvote:
            handleVote(.upvoted)
        case .downvote:
            handleVote(.downvoted)
        case .save:
            handleSave()
        case .share:
            break
        case .reply:
            showingReply = true
        case .profile:
            if !isDeletedUser {
                navigationPath.navigate(to: .userProfile(username: comment.author))
            }
        case .copyLink:
            break
        case .none:
            break
        }
    }
}
