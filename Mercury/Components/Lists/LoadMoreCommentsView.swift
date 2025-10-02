import SwiftUI

struct LoadMoreCommentsView: View {
    let moreComments: MoreComments
    let post: RedditPost
    let sort: CommentSort
    let isLoading: Bool
    let onStartLoad: (() -> Void)?
    let onLoadMore: ([RedditComment]) -> Void
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
                                .appFont(.body, weight: .semibold)
                        }
                    }
                    .disabled(isLoading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 24)
            } else {
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
                                .appFont(.caption, weight: .medium)
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
        guard !isLoading else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        onStartLoad?()
        Task {
            do {
                let isRootLevel = (moreComments.depth == 0 && moreComments.parentId == nil)
                let isRootPagination = isRootLevel && moreComments.name == "root_pagination"
                if isRootPagination {
                    let afterParam = moreComments.children.first
                    let commentResponses = try await redditAPI.fetchPostComments(
                        postId: post.id,
                        sort: sort,
                        limit: 25,
                        after: afterParam
                    )
                    var newComments: [RedditComment] = []
                    var nextAfter: String? = nil
                    if commentResponses.count > 1 {
                        let listing = commentResponses[1]
                        newComments = listing.flattenedComments
                        nextAfter = listing.data.after
                    }
                    await MainActor.run {
                        if let onLoadMoreRootPage = onLoadMoreRootPage {
                            onLoadMoreRootPage(newComments, nextAfter)
                        } else {
                            onLoadMore(newComments)
                        }
                    }
                } else {
                    var commentIds = moreComments.children.isEmpty && !moreComments.name.isEmpty ? [moreComments.name] : moreComments.children
                    if commentIds.count > 25 { commentIds = Array(commentIds.prefix(25)) }
                    let newComments = try await redditAPI.fetchMoreComments(
                        postId: post.id,
                        commentIds: commentIds,
                        sort: sort
                    )
                    await MainActor.run {
                        if isRootLevel, let onLoadMoreRootPage = onLoadMoreRootPage {
                            onLoadMoreRootPage(newComments, nil)
                        } else {
                            onLoadMore(newComments)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    onError?()
                }
            }
        }
    }
}
