//
//  PostActionToolbar.swift
//  Mercury
//
//

import SwiftUI
import Defaults

struct PostActionToolbar: View {
    let post: RedditPost
    @Binding var voteState: RedditPost.VoteState
    @Binding var displayScore: Int
    @Binding var isVoting: Bool
    @Binding var savedState: Bool
    let onVote: (RedditPost.VoteState) -> Void
    let onReply: (() -> Void)?
    let onShare: () -> Void
    let onSave: () -> Void
    let onCopyLink: (() -> Void)?
    let onOpenOriginal: (() -> Void)?
    let onDownload: (() -> Void)?
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
    @Default(.postNormalShowVoting) private var postShowVoting
    
    var body: some View {
        HStack(spacing: size == .large ? 20 : 12) {
            if size == .compact {
    
                    Pill() {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.callout)
                            Text(post.commentsText)
                                .appFont(.caption, weight: .medium)
                        }
                        .foregroundStyle(secondaryColor)
                    }
                
            }
            
            if size == .large {
                Spacer()
                
                // Large toolbar actions on the right (icon-only)
                HStack(spacing: 8) {
                    if let onReply = onReply, !post.locked, !post.archived {
                        Button(action: onReply) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(secondaryColor)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onSave) {
                        Image(systemName: savedState ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(savedState ? accentColor : secondaryColor)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(secondaryColor)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                        Menu {
                            if let onDownload = onDownload, post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery {
                                Button(action: onDownload) {
                                    let downloadLabel = switch post.postType {
                                    case .video: "Download Video"
                                    case .gif: "Download GIF"
                                    case .image: "Download Image"
                                    case .gallery: "Download Gallery"
                                    default: "Download"
                                    }
                                    Label(downloadLabel, systemImage: "arrow.down.circle")
                                }
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
                            Pill(size: .small) {
                                Image(systemName: "ellipsis")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14, height: 14)
                            }
                        
                    }
                }
            } else {
                Spacer()
                
                // Voting cluster for compact size
                if postShowVoting {
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
    }
    
    // MARK: - Color Properties
    
    private var secondaryColor: Color {
        colorScheme == .dark ? .white : .secondary
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? .white : .accentColor
    }
}
