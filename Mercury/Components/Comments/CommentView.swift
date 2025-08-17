//
//  CommentView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct CommentView: View {
    let comment: RedditComment
    let depth: Int
    let post: RedditPost
    let isCollapsed: Bool
    let onCollapseToggle: () -> Void
    
    @State private var voteState: RedditComment.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(comment: RedditComment, depth: Int, post: RedditPost, isCollapsed: Bool = false, onCollapseToggle: @escaping () -> Void = {}) {
        self.comment = comment
        self.depth = depth
        self.post = post
        self.isCollapsed = isCollapsed
        self.onCollapseToggle = onCollapseToggle
        self._voteState = State(initialValue: comment.currentVoteState)
        self._displayScore = State(initialValue: comment.displayScore)
    }
    
    var body: some View {
        Card(style: .comment(depth: depth, accentColor: depth > 0 ? depthColor : nil)) {
            VStack(alignment: .leading, spacing: 8) {
                commentHeader
                
                if !isCollapsed {
                    commentBody
                    commentActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onCollapseToggle()
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
    }
    
    private var commentBody: some View {
        Group {
            if comment.body == "[deleted]" || comment.body == "[removed]" {
                Text(comment.body)
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
    
    private var depthColor: Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if depth == 0 {
            return .clear
        }
        let colorIndex = (depth - 1) % threadColors.count
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
}
