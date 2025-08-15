//
//  LoadMoreCommentsView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

struct LoadMoreCommentsView: View {
    let moreComments: MoreComments
    let post: RedditPost
    let isLoading: Bool
    let onStartLoad: (() -> Void)?
    let onLoadMore: ([RedditComment]) -> Void
    let onError: (() -> Void)?
    @Environment(\.redditAPI) private var redditAPI
    
    init(moreComments: MoreComments, post: RedditPost, isLoading: Bool = false, onStartLoad: (() -> Void)? = nil, onLoadMore: @escaping ([RedditComment]) -> Void, onError: (() -> Void)? = nil) {
        self.moreComments = moreComments
        self.post = post
        self.isLoading = isLoading
        self.onStartLoad = onStartLoad
        self.onLoadMore = onLoadMore
        self.onError = onError
    }
    
    var body: some View {
        Card(
            style: CardStyle(
                padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
                cornerRadius: 12,
                backgroundColor: .blue.opacity(0.08),
                borderColor: .blue.opacity(0.2),
                borderWidth: 1,
                accentColor: depthColor,
                accentWidth: 3,
                accentPosition: .leading
            ),
            interactionMode: .tappable {
                loadMoreComments()
            }
        ) {
            HStack(spacing: 12) {
                // Fixed width icon area to prevent shifting
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.blue)
                    } else {
                        Image(systemName: "ellipsis")
                            .symbolRenderingMode(.hierarchical)
                            .font(.callout)
                    }
                }
                .foregroundStyle(.blue)
                .frame(width: 20, height: 20) // Fixed size
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(loadingText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    
                    // Always show subtitle to maintain height
                    Text(isLoading ? "Please wait..." : "Tap to continue thread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Fixed width chevron area to prevent shifting
                Group {
                    if !isLoading {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    } else {
                        // Invisible spacer to maintain width
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0)
                    }
                }
                .frame(width: 12) // Fixed width
            }
            .frame(minHeight: 44) // Fixed minimum height
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .padding(.leading, CGFloat(moreComments.depth * 16)) // Match comment indentation exactly
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: isLoading)
    }
    
    private var depthColor: Color {
        let threadColors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .yellow]
        if moreComments.depth == 0 {
            return .blue
        }
        let colorIndex = (moreComments.depth - 1) % threadColors.count
        return threadColors[colorIndex].opacity(0.8)
    }
    
    private var loadingText: String {
        if isLoading {
            return "Loading replies..."
        } else if moreComments.count > 0 {
            return "Load \(moreComments.count) more replies"
        } else {
            return "Load more replies"
        }
    }
    
    private func loadMoreComments() {
        guard !isLoading else { 
            print("🔄 LoadMoreComments: Already loading, skipping")
            return 
        }
        
        // Haptic feedback on tap
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🔄 LoadMoreComments: Starting load for more ID: \(moreComments.id), children: \(moreComments.children.count), count: \(moreComments.count)")
        
        // Notify parent to start loading state
        onStartLoad?()
        
        Task {
            do {
                print("🔄 LoadMoreComments: Calling API for post: \(post.id) with children: \(moreComments.children)")
                let newComments = try await redditAPI.fetchMoreComments(
                    postId: post.id,
                    commentIds: moreComments.children
                )
                
                print("🔄 LoadMoreComments: API returned \(newComments.count) comments")
                
                await MainActor.run {
                    onLoadMore(newComments)
                }
            } catch {
                await MainActor.run {
                    print("❌ LoadMoreComments: Failed to load more comments: \(error)")
                    onError?()
                }
            }
        }
    }
}

