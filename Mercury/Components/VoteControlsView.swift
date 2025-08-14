//
//  VoteControlsView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct VoteControlsView: View {
    @Binding var post: RedditPost
    let onVote: (RedditPost.VoteState) -> Void
    let isLoading: Bool
    let orientation: Orientation
    
    enum Orientation {
        case vertical
        case horizontal
    }
    
    var body: some View {
        Group {
            switch orientation {
            case .vertical:
                verticalLayout
            case .horizontal:
                horizontalLayout
            }
        }
        .disabled(!post.canVote || isLoading)
        .opacity(!post.canVote ? 0.6 : 1.0)
    }
    
    private var verticalLayout: some View {
        VStack(spacing: 4) {
            upvoteButton
            scoreView
            downvoteButton
        }
    }
    
    private var horizontalLayout: some View {
        HStack(spacing: 8) {
            upvoteButton
            scoreView
            downvoteButton
        }
    }
    
    private var upvoteButton: some View {
        Button(action: {
            guard !isLoading else { return }
            let newState: RedditPost.VoteState = post.currentVoteState == .upvoted ? .neutral : .upvoted
            onVote(newState)
        }) {
            Image(systemName: post.currentVoteState == .upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(upvoteColor)
        }
        .buttonStyle(AppleVoteButtonStyle())
        .accessibilityLabel("Upvote post")
        .accessibilityValue(post.currentVoteState == .upvoted ? "Upvoted" : "Not upvoted")
        .disabled(isLoading)
    }
    
    private var downvoteButton: some View {
        Button(action: {
            guard !isLoading else { return }
            let newState: RedditPost.VoteState = post.currentVoteState == .downvoted ? .neutral : .downvoted
            onVote(newState)
        }) {
            Image(systemName: post.currentVoteState == .downvoted ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(downvoteColor)
        }
        .buttonStyle(AppleVoteButtonStyle())
        .accessibilityLabel("Downvote post")
        .accessibilityValue(post.currentVoteState == .downvoted ? "Downvoted" : "Not downvoted")
        .disabled(isLoading)
    }
    
    private var scoreView: some View {
        Text(post.scoreText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(scoreColor)
            .monospacedDigit()
            .animation(.easeInOut(duration: 0.2), value: post.displayScore)
            .accessibilityLabel("Post score \(post.scoreText)")
    }
    
    private var upvoteColor: Color {
        switch post.currentVoteState {
        case .upvoted:
            return .accentColor
        default:
            return .secondary
        }
    }
    
    private var downvoteColor: Color {
        switch post.currentVoteState {
        case .downvoted:
            return .purple
        default:
            return .secondary
        }
    }
    
    private var scoreColor: Color {
        switch post.currentVoteState {
        case .upvoted:
            return .accentColor
        case .downvoted:
            return .purple
        case .neutral:
            return .secondary
        }
    }
}

struct AppleVoteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .frame(minWidth: 32, minHeight: 32)
    }
}

#Preview {
    VStack(spacing: 20) {
        VoteControlsView(
            post: .constant(RedditPost.samplePost),
            onVote: { _ in },
            isLoading: false,
            orientation: .vertical
        )
        
        VoteControlsView(
            post: .constant(RedditPost.samplePost),
            onVote: { _ in },
            isLoading: false,
            orientation: .horizontal
        )
    }
    .padding()
}

extension RedditPost {
    static var samplePost: RedditPost {
        let data = """
        {
            "id": "sample",
            "subreddit": "apple",
            "title": "Sample Post Title",
            "author": "user123",
            "permalink": "/r/apple/comments/sample/",
            "domain": "example.com",
            "score": 1234,
            "upvote_ratio": 0.85,
            "num_comments": 42,
            "created_utc": 1700000000,
            "ups": 1234,
            "downs": 0,
            "over_18": false,
            "spoiler": false,
            "pinned": false,
            "stickied": false,
            "locked": false,
            "archived": false,
            "gilded": 0,
            "saved": false,
            "hidden": false,
            "clicked": false,
            "visited": false,
            "is_video": false
        }
        """.data(using: .utf8)!
        
        return try! JSONDecoder().decode(RedditPost.self, from: data)
    }
}
