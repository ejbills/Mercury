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
            VoteButton(
                direction: .up,
                isActive: voteState == .upvoted,
                size: size == .large ? .large : .medium,
                colorScheme: colorScheme == .dark ? .dark : .light,
                disabled: isVoting || !post.canVote
            ) {
                onVote(voteState == .upvoted ? .neutral : .upvoted)
            }
            
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
            VoteButton(
                direction: .down,
                isActive: voteState == .downvoted,
                size: size == .large ? .large : .medium,
                colorScheme: colorScheme == .dark ? .dark : .light,
                disabled: isVoting || !post.canVote
            ) {
                onVote(voteState == .downvoted ? .neutral : .downvoted)
            }
        }
    }
    
    // MARK: - Computed Properties
    
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
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .secondary
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
