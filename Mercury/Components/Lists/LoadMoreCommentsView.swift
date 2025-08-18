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
    let sort: CommentSort
    let isLoading: Bool
    let onStartLoad: (() -> Void)?
    let onLoadMore: ([RedditComment]) -> Void
    // Optional: for root-level pagination, deliver next after token too
    let onLoadMoreRootPage: (([RedditComment], String?) -> Void)?
    let onError: (() -> Void)?
    let depthColor: Color?
    @Environment(\.redditAPI) private var redditAPI
    
    init(
        moreComments: MoreComments,
        post: RedditPost,
        sort: CommentSort,
        isLoading: Bool = false,
        onStartLoad: (() -> Void)? = nil,
        onLoadMore: @escaping ([RedditComment]) -> Void,
        onLoadMoreRootPage: (([RedditComment], String?) -> Void)? = nil,
        onError: (() -> Void)? = nil,
        depthColor: Color? = nil
    ) {
        self.moreComments = moreComments
        self.post = post
        self.sort = sort
        self.isLoading = isLoading
        self.onStartLoad = onStartLoad
        self.onLoadMore = onLoadMore
        self.onLoadMoreRootPage = onLoadMoreRootPage
        self.onError = onError
        self.depthColor = depthColor
    }
    
    var body: some View {
        let isRootButton = (moreComments.depth == 0) && (moreComments.parentId == nil) && (moreComments.name == "root_pagination" || moreComments.name == "root_more_children")
        
        Group {
            if isRootButton {
                // Root-level: centered, prominent pill
                HStack {
                    Spacer(minLength: 0)
                    Pill(action: loadMoreComments) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.headline)
                            }
                            let nextCount = max(moreComments.children.count, 25)
                            Text(isLoading ? "Loading more comments…" : "Load \(nextCount) more comments")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)

                .padding(.horizontal, 12)
                .padding(.vertical, 24)
            } else {
                // Nested: left-aligned pill
                HStack {
                    Pill(action: loadMoreComments, size: .regular) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.bubble")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }
                            Text(isLoading ? "Loading…" : "Show more replies")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(isLoading)
                    Spacer()
                }
                .foregroundStyle(.secondary)

            }
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
                // Check if this is root-level; disambiguate pagination token vs children ids
                let isRootLevel = (moreComments.depth == 0 && moreComments.parentId == nil)
                let isRootPagination = isRootLevel && moreComments.name == "root_pagination"
                
                if isRootPagination {
                    print("🔄 LoadMoreComments: Root-level pagination request for post: \(post.id)")
                    
                    // For root-level, we need to paginate comments, not fetch specific comment children
                    // Use the first child as the "after" parameter for pagination
                    let afterParam = moreComments.children.first
                    
                    let commentResponses = try await redditAPI.fetchPostComments(
                        postId: post.id, 
                        sort: sort,
                        limit: 25,
                        after: afterParam
                    )
                    
                    // Extract comments from the response
                    var newComments: [RedditComment] = []
                    var nextAfter: String? = nil
                    if commentResponses.count > 1 {
                        let listing = commentResponses[1]
                        newComments = listing.flattenedComments
                        nextAfter = listing.data.after
                    }
                    
                    print("🔄 LoadMoreComments: Root-level pagination returned \(newComments.count) comments")
                    
                    await MainActor.run {
                        if let onLoadMoreRootPage = onLoadMoreRootPage {
                            onLoadMoreRootPage(newComments, nextAfter)
                        } else {
                            onLoadMore(newComments)
                        }
                    }
                } else {
                    print("🔄 LoadMoreComments: \(isRootLevel ? "Root" : "Nested") MoreComments request for children: \(moreComments.children.prefix(5))\(moreComments.children.count > 5 ? "..." : "") (total=\(moreComments.children.count))")
                    
                    // If children array is empty but we have a name (comment ID), use that instead
                    var commentIds = moreComments.children.isEmpty && !moreComments.name.isEmpty ? 
                        [moreComments.name] : moreComments.children
                    // Limit batch size to avoid oversized requests
                    if commentIds.count > 25 { commentIds = Array(commentIds.prefix(25)) }
                    
                    print("🔄 LoadMoreComments: Using comment IDs (\(commentIds.count)): \(commentIds.prefix(5))\(commentIds.count > 5 ? "..." : "")")
                    let newComments = try await redditAPI.fetchMoreComments(
                        postId: post.id,
                        commentIds: commentIds,
                        sort: sort
                    )
                    
                    print("🔄 LoadMoreComments: API returned \(newComments.count) comments for \(isRootLevel ? "root" : "nested") more")
                    
                    await MainActor.run {
                        if isRootLevel, let onLoadMoreRootPage = onLoadMoreRootPage {
                            onLoadMoreRootPage(newComments, nil) // nil after (morechildren path)
                        } else {
                            onLoadMore(newComments)
                        }
                    }
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
