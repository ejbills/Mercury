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
    let depthColor: Color?
    @Environment(\.redditAPI) private var redditAPI
    
    init(moreComments: MoreComments, post: RedditPost, isLoading: Bool = false, onStartLoad: (() -> Void)? = nil, onLoadMore: @escaping ([RedditComment]) -> Void, onError: (() -> Void)? = nil, depthColor: Color? = nil) {
        self.moreComments = moreComments
        self.post = post
        self.isLoading = isLoading
        self.onStartLoad = onStartLoad
        self.onLoadMore = onLoadMore
        self.onError = onError
        self.depthColor = depthColor
    }
    
    var body: some View {
        HStack {
            Button(action: loadMoreComments) {
            HStack(spacing: 8) {
                // Icon
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.bubble")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }
                
                Text(isLoading ? "Loading..." : "Show more replies")
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.quaternary.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(depthColor?.opacity(0.3) ?? Color(uiColor: UIColor.tertiaryLabel), lineWidth: 0.5)
                    )
            )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .sensoryFeedback(.impact(weight: .medium), trigger: isLoading)
            
            Spacer()
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
                
                // If children array is empty but we have a name (comment ID), use that instead
                let commentIds = moreComments.children.isEmpty && !moreComments.name.isEmpty ? 
                    [moreComments.name] : moreComments.children
                
                print("🔄 LoadMoreComments: Using comment IDs: \(commentIds)")
                let newComments = try await redditAPI.fetchMoreComments(
                    postId: post.id,
                    commentIds: commentIds
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

