import SwiftUI

struct PostCommentsView: View {
    let post: RedditPost
    let targetCommentId: String?

    @State private var threadManager = CommentThreadManager()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var commentSort: CommentSort = .best
    @State private var showingSortOptions = false
    @State private var loadingRootMoreIds: Set<String> = []
    @State private var selectedPost: RedditPost?
    @State private var videoHandoffState: VideoHandoffState?
    @Namespace private var mediaNamespace
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var singleThreadMode: Bool = false
    @State private var swipeLockScroll: Bool = false

        init(post: RedditPost, targetCommentId: String? = nil) {
            self.post = post
            self.targetCommentId = targetCommentId
        }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                        PostRowView(
                        post: post, 
                        namespace: mediaNamespace, 
                        selectedPost: $selectedPost,
                        showLargeToolbar: true,
                        showFullText: true,
                        onRootReplyPosted: { newComment in
                            threadManager.addRootComment(newComment)
                        },
                        onVideoHandoff: { handoffState in
                            videoHandoffState = handoffState
                        }
                    )
                        if targetCommentId != nil { modePicker }
                        commentsSection
                    }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDisabled(swipeLockScroll)
            .onChange(of: threadManager.commentThreads.count) { _, _ in
                scrollToTargetIfNeeded(proxy: proxy)
            }
            .onAppear {
                scrollToTargetIfNeeded(proxy: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: .swipeInteractionBegan)) { _ in
                swipeLockScroll = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .swipeInteractionEnded)) { _ in
                swipeLockScroll = false
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortButton
            }
        }
        .refreshable {
            await MainActor.run {
                threadManager = CommentThreadManager()
                isLoading = true
                errorMessage = nil
            }
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
        .fullScreenCover(item: $selectedPost) { post in
            MediaDetailView(
                post: post,
                namespace: mediaNamespace,
                videoHandoffState: videoHandoffState,
                onVideoHandoffReturn: { handoffState in
                    videoHandoffState = handoffState
                }
            )
        }
    }
    
    
    private var commentsSection: some View {
        Group {
            if isLoading && threadManager.commentThreads.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage, threadManager.commentThreads.isEmpty {
                errorView(message: errorMessage)
            } else if threadManager.commentThreads.isEmpty {
                emptyCommentsView
            } else {
                commentsListView
            }
        }
    }
    
    private var modePicker: some View {
            HStack(spacing: 8) {
                Pill(action: {
                    guard !singleThreadMode else { return }
                    singleThreadMode = true
                    Task { await loadComments() }
                }, size: .regular) {
                    HStack(spacing: 6) {
                        Image(systemName: singleThreadMode ? "checkmark.circle.fill" : "text.bubble")
                            .foregroundStyle(singleThreadMode ? .blue : .secondary)
                        Text("Single comment thread")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Pill(action: {
                    guard singleThreadMode else { return }
                    singleThreadMode = false
                    Task { await loadComments() }
                }, size: .regular) {
                    HStack(spacing: 6) {
                        Image(systemName: !singleThreadMode ? "checkmark.circle.fill" : "text.bubble.fill")
                            .foregroundStyle(!singleThreadMode ? .blue : .secondary)
                        Text("See full discussion")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
    
    private var commentsListView: some View {
        VStack(spacing: 0) {
            let allComments = threadManager.commentThreads.map { $0.parentComment }
            
            CommentThreadView(
                comments: allComments,
                post: post,
                sort: commentSort
            )
            
            if !threadManager.moreObjects.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(threadManager.moreObjects, id: \.id) { more in
                        Group {
                            if more.name == "root_pagination" {
                                LoadMoreCommentsView(
                                    moreComments: more,
                                    post: post,
                                    sort: commentSort,
                                    isLoading: loadingRootMoreIds.contains(more.id),
                                    onStartLoad: { loadingRootMoreIds.insert(more.id) },
                                    onLoadMore: { _ in },
                                    onLoadMoreRootPage: { newComments, nextAfter in
                                        loadingRootMoreIds.remove(more.id)
                                        threadManager.appendRootPage(newComments: newComments, nextAfter: nextAfter)
                                    },
                                    onError: {
                                        loadingRootMoreIds.remove(more.id)
                                    }
                                )
                            } else {
                                LoadMoreCommentsView(
                                    moreComments: more,
                                    post: post,
                                    sort: commentSort,
                                    isLoading: loadingRootMoreIds.contains(more.id),
                                    onStartLoad: { loadingRootMoreIds.insert(more.id) },
                                    onLoadMore: { newComments in
                                        loadingRootMoreIds.remove(more.id)
                                        let consumed = more.children.count
                                        threadManager.appendRootChildrenPage(newComments: newComments, consumedCount: consumed)
                                    },
                                    onLoadMoreRootPage: nil,
                                    onError: {
                                        loadingRootMoreIds.remove(more.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
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
        }
    }
    
    // MARK: - Helper Functions
    
    @MainActor
    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await redditAPI.fetchPostComments(
                            postId: post.id,
                            sort: commentSort,
                            focusCommentId: singleThreadMode ? targetCommentId : nil,
                            context: singleThreadMode ? 3 : nil
                        )
            
            if response.count > 1 {
                let commentsResponse = response[1]
                let comments = commentsResponse.flattenedComments
                let moreObjects = commentsResponse.moreComments
                let rootAfter = commentsResponse.data.after
                
                threadManager.loadInitialComments(comments, moreObjects: moreObjects, rootAfter: rootAfter)
            } else {
                threadManager.loadInitialComments([], moreObjects: [], rootAfter: nil)
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func scrollToTargetIfNeeded(proxy: ScrollViewProxy) {
        guard let targetId = targetCommentId, !targetId.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        }
    }
}
