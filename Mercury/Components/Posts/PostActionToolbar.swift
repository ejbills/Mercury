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
    let showScore: Bool
    let showCommentCount: Bool
    let showVoting: Bool

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
        HStack(spacing: 8) {
            // Voting buttons (for compact size in feed)
            if size == .compact && showVoting {
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

            // For large size (comments page), show upvote count badge
            if size == .large {
                if showScore {
                    Pill(action: {
                        onVote(voteState == .upvoted ? .neutral : .upvoted)
                    }, size: .regular) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up")
                                .font(.callout)
                            Text(scoreText)
                                .appFont(.caption, weight: .medium)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(scoreColor)
                    }
                }

                if showCommentCount {
                    Pill {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.callout)
                            Text(post.commentsText)
                                .appFont(.caption, weight: .medium)
                        }
                        .foregroundStyle(secondaryColor)
                    }
                }
            }

            Spacer()

            // Action buttons - unified Pill styling
            HStack(spacing: 8) {
                if let onReply = onReply, !post.locked, !post.archived {
                    Pill(action: onReply, size: .regular) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.callout)
                        }
                        .foregroundStyle(secondaryColor)
                    }
                }

                Pill(action: onSave, size: .regular) {
                    HStack(spacing: 4) {
                        Image(systemName: savedState ? "bookmark.fill" : "bookmark")
                            .font(.callout)
                    }
                    .foregroundStyle(savedState ? accentColor : secondaryColor)
                }

                Pill(action: onShare, size: .regular) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.callout)
                    }
                    .foregroundStyle(secondaryColor)
                }

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
                    Pill(size: .regular) {
                        Image(systemName: "ellipsis")
                            .font(.callout)
                            .foregroundStyle(secondaryColor)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Color Properties

    private var secondaryColor: Color {
        colorScheme == .dark ? .white : .secondary
    }

    private var accentColor: Color {
        colorScheme == .dark ? .white : .accentColor
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
        case .neutral: return secondaryColor
        }
    }
}
