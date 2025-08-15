//
//  CommentCard.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

struct CommentCard: View {
    let commentThread: CommentThread
    let post: RedditPost
    @State private var isCollapsed = false
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent comment
            CommentRowInCard(
                comment: commentThread.parentComment,
                post: post,
                threadKinds: [],
                isParent: true,
                isCollapsed: $isCollapsed
            )
            
            // Child replies (only show if not collapsed)
            if !isCollapsed && !commentThread.replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(commentThread.replies.enumerated()), id: \.offset) { index, reply in
                        let isLast = index == commentThread.replies.count - 1
                        let parentKinds: [ThreadLineKind] = []
                        
                        RecursiveCommentView(
                            comment: reply,
                            post: post,
                            ancestorKinds: parentKinds,
                            isLast: isLast
                        )
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
    }
    
    private var threadColors: [Color] {
        [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
    }
}

struct CommentThread {
    let parentComment: RedditComment
    let replies: [RedditComment]
    
    init(parentComment: RedditComment, allComments: [RedditComment]) {
        self.parentComment = parentComment
        self.replies = Self.buildDirectReplies(for: parentComment)
    }
    
    private static func buildDirectReplies(for parent: RedditComment) -> [RedditComment] {
        // Only get direct children, don't flatten the hierarchy
        guard let parentReplies = parent.replies else { return [] }
        return parentReplies.comments
    }
}

struct RecursiveCommentView: View {
    let comment: RedditComment
    let post: RedditPost
    let ancestorKinds: [ThreadLineKind]
    let isLast: Bool
    
    @State private var isCollapsed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // This comment
            let threadKinds = comment.generateThreadKinds(isLast: isLast, ancestorKinds: ancestorKinds)
            CommentRowInCard(
                comment: comment,
                post: post,
                threadKinds: threadKinds,
                isParent: comment.replies?.comments.isEmpty == false,
                isCollapsed: $isCollapsed
            )
            
            // Child replies (only show if not collapsed)  
            if !isCollapsed, let replies = comment.replies?.comments, !replies.isEmpty {
                VStack(alignment: .leading, spacing: -1) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { index, childReply in
                        let childIsLast = index == replies.count - 1
                        let childAncestorKinds = threadKinds
                        
                        RecursiveCommentView(
                            comment: childReply,
                            post: post,
                            ancestorKinds: childAncestorKinds,
                            isLast: childIsLast
                        )
                    }
                }
            }
        }
    }
}

struct CommentRowInCard: View {
    let comment: RedditComment
    let post: RedditPost
    let threadKinds: [ThreadLineKind]
    let isParent: Bool
    @Binding var isCollapsed: Bool
    
    @State private var isVoting = false
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(comment: RedditComment, post: RedditPost, threadKinds: [ThreadLineKind], isParent: Bool, isCollapsed: Binding<Bool>) {
        self.comment = comment
        self.post = post
        self.threadKinds = threadKinds
        self.isParent = isParent
        self._isCollapsed = isCollapsed
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Threading lines
            if !threadKinds.isEmpty {
                CommentThreadLines(
                    threadKinds: threadKinds,
                    colors: threadColors,
                    isLastInThread: threadKinds.last == .curve
                )
        
            }
            
            // Profile picture
            UserAvatar(username: comment.author, size: 32)
                .onTapGesture {
                    navigationPath.navigate(to: .userProfile(username: comment.author))
                }
            
            // Comment content
            VStack(alignment: .leading, spacing: 6) {
                commentHeader
                
                if !isCollapsed || !isParent {
                    commentBody
                    commentActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            // Subtle comment boundary with left accent
            Rectangle()
                .fill(.separator.opacity(0.02))
        }
        .overlay(alignment: .leading) {
            // Threading origin indicator
            if !threadKinds.isEmpty {
                Rectangle()
                    .fill(threadColors.first?.opacity(0.3) ?? .clear)
                    .frame(width: 2)
            }
        }
    }
    
    private var threadColors: [Color] {
        [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
    }
    
    private var commentHeader: some View {
        HStack(spacing: 8) {
            // Author name and badges
            HStack(spacing: 4) {
                Text(comment.author)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(authorColor)
                
                if comment.isSubmitter {
                    Text("OP")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
                
                if let distinguished = comment.distinguished {
                    Text(distinguished.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green, in: Capsule())
                }
            }
            
            Spacer()
            
            // Score and time
            HStack(spacing: 8) {
                if !comment.scoreHidden {
                    Text(scoreText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                }
                
                Text(comment.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Collapse button for parent only
                if isParent {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            isCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
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
            } else if !comment.body.isEmpty {
                Text(comment.body)
                    .font(.callout)
                    .lineLimit(nil)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var deletedCommentView: some View {
        HStack(spacing: 8) {
            Image(systemName: comment.body == "[deleted]" ? "trash" : "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(comment.body == "[deleted]" ? "Comment deleted by user" : "Comment removed by moderator")
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var commentActions: some View {
        HStack(spacing: 16) {
            // Vote controls
            HStack(spacing: 4) {
                Button {
                    handleVote(.upvoted)
                } label: {
                    Image(systemName: voteState == .upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(voteState == .upvoted ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
                
                Button {
                    handleVote(.downvoted)
                } label: {
                    Image(systemName: voteState == .downvoted ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(voteState == .downvoted ? Color.purple : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isVoting || !comment.canVote)
                .sensoryFeedback(.selection, trigger: voteState)
            }
            
            // Reply button
            Button {
                // TODO: Implement reply functionality
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .labelStyle(.iconOnly)
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            
            // Save button
            Button {
                // TODO: Implement save functionality
            } label: {
                Label(comment.saved ? "Saved" : "Save", 
                      systemImage: comment.saved ? "bookmark.fill" : "bookmark")
                    .labelStyle(.iconOnly)
                    .font(.callout)
                    .foregroundStyle(comment.saved ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helper Properties
    
    private var authorColor: Color {
        if comment.isSubmitter {
            return Color.accentColor
        } else if comment.distinguished != nil {
            return Color.green
        } else {
            return Color.primary
        }
    }
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted:
            return Color.accentColor
        case .downvoted:
            return Color.purple
        case .neutral:
            return Color.secondary
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
    
    private func handleVote(_ newVoteState: RedditComment.VoteState) {
        let targetState = voteState == newVoteState ? .neutral : newVoteState
        
        // Store original state for potential reversion
        let originalVoteState = voteState
        let originalScore = displayScore
        
        // Apply optimistic update
        voteState = targetState
        switch (originalVoteState, targetState) {
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
        
        isVoting = true
        
        Task {
            do {
                let voteDirection: VoteDirection = switch targetState {
                case .upvoted: .upvote
                case .downvoted: .downvote
                case .neutral: .neutral
                }
                
                try await redditAPI.voteOnComment(commentId: comment.id, voteDirection: voteDirection)
                
                await MainActor.run {
                    isVoting = false
                }
            } catch {
                await MainActor.run {
                    // Revert optimistic update on error
                    voteState = originalVoteState
                    displayScore = originalScore
                    isVoting = false
                }
                print("Failed to vote on comment: \(error)")
            }
        }
    }
}

#Preview {
    let sampleComment = RedditComment(
        id: "sample",
        subreddit: "apple",
        author: "sampleuser",
        body: "This is a sample comment that demonstrates the new card-based design.",
        bodyHtml: nil,
        score: 42,
        depth: 0,
        created: nil,
        createdUtc: Date().timeIntervalSince1970 - 3600,
        edited: nil,
        distinguished: nil,
        stickied: false,
        saved: false,
        likes: nil,
        permalink: "/r/apple/comments/sample/comment/",
        parentId: nil,
        linkId: "t3_post123",
        isSubmitter: false,
        scoreHidden: false,
        controversiality: 0,
        authorFlairText: nil,
        gilded: 0,
        collapsed: false,
        collapsedReason: nil,
        archived: false,
        locked: false,
        replies: nil
    )
    
    let sampleThread = CommentThread(parentComment: sampleComment, allComments: [])
    let samplePost = RedditPost.samplePost
    
    CommentCard(commentThread: sampleThread, post: samplePost)
        .padding()
}