//
//  PostCommentsView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

struct PostCommentsView: View {
    let post: RedditPost
    @State private var threadManager = CommentThreadManager()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var commentSort: CommentSort = .best
    @State private var showingSortOptions = false
    @Namespace private var mediaNamespace
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Post header with large toolbar
                PostRowView(
                    post: post, 
                    namespace: mediaNamespace, 
                    selectedPost: .constant(nil),
                    showLargeToolbar: true
                )
                
                // Comments section
                commentsSection
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortButton
            }
        }
        .refreshable {
            await loadComments()
        }
        .task {
            await loadComments()
        }
        .confirmationDialog("Sort Comments", isPresented: $showingSortOptions) {
            ForEach(CommentSort.allCases, id: \.self) { sort in
                Button(sort.displayName) {
                    commentSort = sort
                    Task {
                        await loadComments()
                    }
                }
            }
        }
    }
    
    
    private var commentsSection: some View {
        Group {
            if isLoading && threadManager.commentThreads.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if threadManager.commentThreads.isEmpty {
                emptyCommentsView
            } else {
                commentsListView
            }
        }
    }
    
    private var commentsListView: some View {
        LazyVStack(spacing: 8) {
            // Display each comment thread (top-level comments with their nested replies)
            ForEach(Array(threadManager.commentThreads.enumerated()), id: \.offset) { index, thread in
                CommentTreeView(
                    comment: thread.parentComment,
                    post: post,
                    isRootComment: true
                )
            }
            
            // Load more comments section
            if !threadManager.moreObjects.isEmpty {
                ForEach(threadManager.moreObjects, id: \.id) { more in
                    LoadMoreCommentsView(
                        moreComments: more,
                        post: post,
                        onLoadMore: { newComments in
                            threadManager.insertMoreComments(newComments, replacingMoreId: more.id)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading comments...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Failed to load comments")
                .font(.headline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadComments()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
    
    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No comments yet")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Be the first to comment on this post")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
    
    private var sortButton: some View {
        Button(action: {
            showingSortOptions = true
        }) {
            HStack(spacing: 4) {
                Text(commentSort.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Functions
    
    @MainActor
    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await redditAPI.fetchPostComments(postId: post.id, sort: commentSort)
            
            // Reddit returns array where [0] is post, [1] is comments
            if response.count > 1 {
                let commentsResponse = response[1]
                let comments = commentsResponse.flattenedComments
                let moreObjects = commentsResponse.moreComments
                
                threadManager.loadInitialComments(comments, moreObjects: moreObjects)
            } else {
                threadManager.loadInitialComments([], moreObjects: [])
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("Failed to load comments: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PostCommentsView(post: RedditPost.samplePost)
            .environment(\.redditAPI, RedditAPIManager())
            .environment(\.navigationPathManager, NavigationPathManager())
    }
}