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
    let onLoadMore: ([RedditComment]) -> Void
    @State private var isLoading = false
    @Environment(\.redditAPI) private var redditAPI
    
    var body: some View {
        Button {
            loadMoreComments()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .foregroundStyle(Color.accentColor)
                
                Text(loadingText)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.separator, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .padding(.horizontal, 16)
        .padding(.leading, CGFloat(moreComments.depth * 12))
        .sensoryFeedback(.selection, trigger: isLoading)
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
        guard !isLoading && !moreComments.children.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let newComments = try await redditAPI.fetchMoreComments(
                    postId: post.id,
                    commentIds: moreComments.children
                )
                
                await MainActor.run {
                    isLoading = false
                    onLoadMore(newComments)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                print("Failed to load more comments: \(error)")
            }
        }
    }
}

#Preview {
    let sampleMore = MoreComments(
        count: 5,
        name: "t1_sample",
        id: "sample",
        parentId: "t1_parent",
        depth: 1,
        children: ["abc123", "def456", "ghi789"]
    )
    
    let samplePost = RedditPost.samplePost
    
    LoadMoreCommentsView(
        moreComments: sampleMore,
        post: samplePost,
        onLoadMore: { _ in }
    )
    .padding()
}