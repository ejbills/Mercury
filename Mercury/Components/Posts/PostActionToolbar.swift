//
//  PostActionToolbar.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct PostActionToolbar: View {
    let post: RedditPost
    @Binding var voteState: RedditPost.VoteState
    @Binding var displayScore: Int
    @Binding var isVoting: Bool
    let onVote: (RedditPost.VoteState) -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onCopyLink: (() -> Void)?
    let onOpenOriginal: (() -> Void)?
    let onCommentsAction: (() -> Void)?
    let colorScheme: PostActionColorScheme
    let size: PostActionSize
    
    enum PostActionColorScheme {
        case light
        case dark
    }
    
    enum PostActionSize {
        case compact
        case large
    }
    
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        HStack(spacing: size == .large ? 20 : 12) {
            // More menu (only for compact size)
            if size == .compact {
                Menu {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: onSave) {
                        Label(post.saved ? "Unsave" : "Save", systemImage: post.saved ? "bookmark.fill" : "bookmark")
                    }
                    
                    if let onCopyLink = onCopyLink {
                        Button(action: onCopyLink) {
                            Label("Copy Link", systemImage: "link")
                        }
                    }
                    
                    if let urlString = post.url, !urlString.isEmpty, let onOpenOriginal = onOpenOriginal {
                        Button(action: onOpenOriginal) {
                            Label("Open Original", systemImage: "safari")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(secondaryColor)
                        .frame(width: 32, height: 32)
                }
            }
            
            // Comments button (conditional)
            if let onCommentsAction = onCommentsAction {
                Pill(action: onCommentsAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.callout)
                        Text(post.commentsText)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(secondaryColor)
                }
            }
            
            if size == .large {
                Spacer()
                
                // Large toolbar actions on the right
                Button(action: onSave) {
                    VStack(spacing: 4) {
                        Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(post.saved ? accentColor : secondaryColor)
                        
                        Text(post.saved ? "Saved" : "Save")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(post.saved ? accentColor : secondaryColor)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: onShare) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(secondaryColor)
                        
                        Text("Share")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryColor)
                    }
                }
                .buttonStyle(.plain)
                
                Menu {
                    if let onCopyLink = onCopyLink {
                        Button(action: onCopyLink) {
                            Label("Copy Link", systemImage: "link")
                        }
                    }
                    
                    if let urlString = post.url, !urlString.isEmpty, let onOpenOriginal = onOpenOriginal {
                        Button(action: onOpenOriginal) {
                            Label("Open Original", systemImage: "safari")
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(secondaryColor)
                        
                        Text("More")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryColor)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                
                // Voting cluster for compact size
                VotingCluster(
                    post: post,
                    voteState: $voteState,
                    displayScore: $displayScore,
                    isVoting: $isVoting,
                    onVote: onVote,
                    colorScheme: colorScheme == .dark ? .dark : .light,
                    size: .compact
                )
            }
        }
    }
    
    // MARK: - Color Properties
    
    private var secondaryColor: Color {
        colorScheme == .dark ? .white : .secondary
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? .white : .accentColor
    }
}

#Preview {
    VStack(spacing: 20) {
        PostActionToolbar(
            post: RedditPost.samplePost,
            voteState: .constant(.neutral),
            displayScore: .constant(42),
            isVoting: .constant(false),
            onVote: { _ in },
            onShare: {},
            onSave: {},
            onCopyLink: {},
            onOpenOriginal: {},
            onCommentsAction: {},
            colorScheme: .light,
            size: .compact
        )
        
        PostActionToolbar(
            post: RedditPost.samplePost,
            voteState: .constant(.upvoted),
            displayScore: .constant(1205),
            isVoting: .constant(false),
            onVote: { _ in },
            onShare: {},
            onSave: {},
            onCopyLink: nil,
            onOpenOriginal: nil,
            onCommentsAction: {},
            colorScheme: .dark,
            size: .large
        )
        .background(.black)
    }
    .padding()
    .environment(\.navigationPathManager, NavigationPathManager())
}