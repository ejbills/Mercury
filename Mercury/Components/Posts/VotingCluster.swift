//
//  VotingCluster.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct VotingCluster: View {
    let post: RedditPost
    @Binding var voteState: RedditPost.VoteState
    @Binding var displayScore: Int
    @Binding var isVoting: Bool
    let onVote: (RedditPost.VoteState) -> Void
    let colorScheme: VotingColorScheme
    let size: VotingSize
    
    enum VotingColorScheme {
        case light
        case dark
    }
    
    enum VotingSize {
        case compact
        case large
    }
    
    var body: some View {
        HStack(spacing: size == .large ? 12 : 8) {
            // Upvote button
            Button {
                onVote(voteState == .upvoted ? .neutral : .upvoted)
            } label: {
                Image(systemName: "arrow.up")
                    .font(size == .large ? .title2 : .callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(voteState == .upvoted ? upvoteActiveColor : inactiveColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(voteState == .upvoted ? upvoteBackgroundColor : Color.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(voteState == .upvoted ? upvoteBackgroundColor : strokeColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isVoting || !post.canVote)
            .sensoryFeedback(.selection, trigger: voteState)
            
            // Score display
            VStack(spacing: 2) {
                Text(scoreText)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
            }
            .frame(minWidth: 50)
            
            // Downvote button
            Button {
                onVote(voteState == .downvoted ? .neutral : .downvoted)
            } label: {
                Image(systemName: "arrow.down")
                    .font(size == .large ? .title2 : .callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(voteState == .downvoted ? downvoteActiveColor : inactiveColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(voteState == .downvoted ? downvoteBackgroundColor : Color.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(voteState == .downvoted ? downvoteBackgroundColor : strokeColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isVoting || !post.canVote)
            .sensoryFeedback(.selection, trigger: voteState)
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonSize: CGFloat {
        size == .large ? 44 : 32
    }
    
    private var cornerRadius: CGFloat {
        size == .large ? 12 : 8
    }
    
    private var scoreText: String {
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
        case .neutral: return colorScheme == .dark ? .white : .primary
        }
    }
    
    private var upvoteActiveColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var downvoteActiveColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var inactiveColor: Color {
        colorScheme == .dark ? .white : .secondary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .secondary
    }
    
    private var upvoteBackgroundColor: Color {
        .orange
    }
    
    private var downvoteBackgroundColor: Color {
        .blue
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)
    }
}

#Preview {
    VStack(spacing: 20) {
        VotingCluster(
            post: RedditPost.samplePost,
            voteState: .constant(.neutral),
            displayScore: .constant(42),
            isVoting: .constant(false),
            onVote: { _ in },
            colorScheme: .light,
            size: .compact
        )
        
        VotingCluster(
            post: RedditPost.samplePost,
            voteState: .constant(.upvoted),
            displayScore: .constant(1205),
            isVoting: .constant(false),
            onVote: { _ in },
            colorScheme: .light,
            size: .large
        )
        
        VotingCluster(
            post: RedditPost.samplePost,
            voteState: .constant(.downvoted),
            displayScore: .constant(12),
            isVoting: .constant(false),
            onVote: { _ in },
            colorScheme: .dark,
            size: .compact
        )
        .background(.black)
    }
    .padding()
}