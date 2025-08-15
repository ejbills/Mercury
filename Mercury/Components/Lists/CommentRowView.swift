//
//  CommentRowView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

struct CommentRowView: View {
    @State var comment: RedditComment
    let post: RedditPost
    @State private var isVoting = false
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @State private var isCollapsed: Bool
    @Environment(\.redditAPI) private var redditAPI
    
    init(comment: RedditComment, post: RedditPost) {
        self.comment = comment
        self.post = post
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
        self._isCollapsed = State(initialValue: comment.isCollapsed)
    }
    
    private var currentComment: RedditComment {
        var updatedComment = comment
        updatedComment.currentVoteState = voteState
        updatedComment.displayScore = displayScore
        updatedComment.isCollapsed = isCollapsed
        return updatedComment
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture
            UserAvatar(username: comment.author, size: 36)
            
            // Comment content
            VStack(alignment: .leading, spacing: 8) {
                commentHeader
                
                if !isCollapsed {
                    commentBody
                    commentActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        }
        .overlay(alignment: .leading) {
            // Leading edge color - only for depth > 0
            if comment.depth > 0 {
                RoundedRectangle(cornerRadius: 16)
                    .fill(depthColor)
                    .frame(width: 3)
            }
        }
        .padding(.leading, CGFloat(comment.depth * 20)) // Apple-style indentation
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Helper Properties
    
    private var depthColor: Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if comment.depth == 0 {
            return .clear // Root comments have no leading edge
        }
        let colorIndex = (comment.depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
    }
    
    // MARK: - Modern iOS 18 Components
    
    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            commentHeader
            
            if !isCollapsed {
                commentBody
                commentActions
            }
        }
    }
    

    
    private var commentHeader: some View {
        HStack(spacing: 8) {
            // Author with modern styling
            HStack(spacing: 4) {
                Text(comment.author)
                    .font(.subheadline)
                    .fontWeight(comment.isSubmitter ? .semibold : .medium)
                    .foregroundStyle(authorColor)
                
                if comment.isSubmitter {
                    Text("OP")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
                
                if let distinguished = comment.distinguished {
                    Text(distinguished.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green, in: Capsule())
                }
            }
            
            Spacer()
            
            // Score and time with modern hierarchy
            HStack(spacing: 8) {
                if !comment.scoreHidden {
                    Text(currentComment.scoreText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                }
                
                Text(comment.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
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
            } else {
                EmptyView()
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
        HStack(spacing: 12) {
            // Vote controls with modern button style
            HStack(spacing: 2) {
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
            
            // Action buttons with modern iOS style
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
                    .foregroundStyle(comment.saved ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - Modern Color Scheme
    
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
    
    private func handleSave() {
        Task {
            do {
                if comment.saved {
                    try await redditAPI.unsaveComment(commentId: comment.id)
                } else {
                    try await redditAPI.saveComment(commentId: comment.id)
                }
                // Note: The comment.saved state would typically be updated by refreshing the comment data
                // For now, we'll handle this silently
            } catch {
                print("Failed to save/unsave comment: \(error)")
            }
        }
    }
}

// Modern button styles removed - using built-in .plain style with sensory feedback

#Preview {
    let sampleComment = RedditComment(
        id: "sample",
        subreddit: "apple",
        author: "sampleuser",
        body: "This is a sample comment that demonstrates how the comment view looks with some text content.",
        bodyHtml: nil,
        score: 42,
        depth: 1,
        created: nil,
        createdUtc: Date().timeIntervalSince1970 - 3600,
        edited: nil,
        distinguished: nil,
        stickied: false,
        saved: false,
        likes: nil,
        permalink: "/r/apple/comments/sample/comment/",
        parentId: "t3_post123",
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
    
    let samplePost = RedditPost.samplePost
    
    VStack {
        CommentRowView(comment: sampleComment, post: samplePost)
        Divider()
        CommentRowView(comment: RedditComment(
            id: "sample2",
            subreddit: "apple",
            author: "OP_user",
            body: "This is an OP comment with deeper nesting.",
            bodyHtml: nil,
            score: 25,
            depth: 2,
            created: nil,
            createdUtc: Date().timeIntervalSince1970 - 1800,
            edited: nil,
            distinguished: nil,
            stickied: false,
            saved: false,
            likes: nil,
            permalink: "/r/apple/comments/sample/comment2/",
            parentId: "t1_sample",
            linkId: "t3_post123",
            isSubmitter: true,
            scoreHidden: false,
            controversiality: 0,
            authorFlairText: nil,
            gilded: 0,
            collapsed: false,
            collapsedReason: nil,
            archived: false,
            locked: false,
            replies: nil
        ), post: samplePost)
    }
    .padding()
}

// MARK: - Sample Data Extension
extension RedditComment {
    init(id: String, subreddit: String?, author: String, body: String, bodyHtml: String?, score: Int, depth: Int, created: Double?, createdUtc: Double?, edited: EditedData?, distinguished: String?, stickied: Bool, saved: Bool, likes: Bool?, permalink: String, parentId: String?, linkId: String?, isSubmitter: Bool, scoreHidden: Bool, controversiality: Int, authorFlairText: String?, gilded: Int, collapsed: Bool, collapsedReason: String?, archived: Bool, locked: Bool, replies: CommentReplies?) {
        self.id = id
        self.subreddit = subreddit
        self.author = author
        self.body = body
        self.bodyHtml = bodyHtml
        self.score = score
        self.depth = depth
        self.created = created
        self.createdUtc = createdUtc
        self.edited = edited
        self.distinguished = distinguished
        self.stickied = stickied
        self.saved = saved
        self.likes = likes
        self.permalink = permalink
        self.parentId = parentId
        self.linkId = linkId
        self.isSubmitter = isSubmitter
        self.scoreHidden = scoreHidden
        self.controversiality = controversiality
        self.authorFlairText = authorFlairText
        self.gilded = gilded
        self.collapsed = collapsed
        self.collapsedReason = collapsedReason
        self.archived = archived
        self.locked = locked
        self.replies = replies
        
        self.displayScore = score
        if let likes = likes {
            self.currentVoteState = likes ? .upvoted : .downvoted
        } else {
            self.currentVoteState = .neutral
        }
        self.isCollapsed = false
    }
}