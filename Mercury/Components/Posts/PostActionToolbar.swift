//
//  PostActionToolbar.swift
//  Mercury
//
//

import SwiftUI

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
    let onCommentsAction: (() -> Void)?
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
    
    var body: some View {
        HStack(spacing: size == .large ? 20 : 12) {
            // More menu (only for compact size)
            if size == .compact {
                Menu {
                    if let onReply = onReply, !post.locked, !post.archived {
                        Button(action: onReply) {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }
                    }
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
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: onSave) {
                        Label(savedState ? "Unsave" : "Save", systemImage: savedState ? "bookmark.fill" : "bookmark")
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

            // No inline Reply pill; Reply lives in the menu only
            
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
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(secondaryColor)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
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
