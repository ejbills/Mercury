import SwiftUI
import Defaults

struct PostCommentsView: View {
    let post: RedditPost
    let targetCommentId: String?

    @State private var threadManager = CommentThreadManager()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var commentSort: CommentSort = .best
    // Old confirmation dialog removed; use Menu anchored in toolbar
    @State private var loadingRootMoreIds: Set<String> = []
    @State private var selectedPost: RedditPost?
    @State private var videoHandoffState: VideoHandoffState?
    @Namespace private var mediaNamespace
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var singleThreadMode: Bool = false
    @State private var commentSearchText: String = ""
    @State private var isSearching: Bool = false
    @State private var filteredComments: [RedditComment] = []
    @State private var isSearchLoading: Bool = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @Default(.postHorizontalPadding) private var postHorizontalPadding
    @Default(.feedBackgroundStyle) private var feedBackgroundStyle
    @Default(.customFeedBackgroundColor) private var customFeedBackgroundColor
    @Default(.commentHorizontalPadding) private var commentHorizontalPadding
    @Default(.postLayoutStyle) private var postLayoutStyle

        init(post: RedditPost, targetCommentId: String? = nil) {
            self.post = post
            self.targetCommentId = targetCommentId
        }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if postLayoutStyle == .compact {
                        VStack(alignment: .leading, spacing: 8) {
                            CompactPostRowView(
                                post: post,
                                namespace: mediaNamespace,
                                selectedPost: $selectedPost,
                                onRootReplyPosted: { newComment in
                                    threadManager.addRootComment(newComment)
                                },
                                allowsNavigation: false
                            )

                            if let bodyText = post.selftext, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                MarkdownRenderer(content: bodyText, compactMode: false, showEmbeddedContent: true)
                                    .padding(.horizontal, CGFloat(postHorizontalPadding))
                            }
                        }
                    } else {
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
                            },
                            allowsNavigation: false
                        )
                    }

                    if targetCommentId != nil {
                        modePicker
                            .padding(.horizontal, CGFloat(commentHorizontalPadding))
                    }

                    commentsSection(proxy: proxy)

                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .feedBackground(style: feedBackgroundStyle, customColor: customFeedBackgroundColor?.color)
            .onChange(of: threadManager.commentThreads.count) { _, _ in
                scrollToTargetIfNeeded(proxy: proxy)
            }
            .onAppear {
                scrollToTargetIfNeeded(proxy: proxy)
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortButton
            }
        }
        .searchable(text: $commentSearchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search comments")
        .onChange(of: commentSearchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            searchDebounceTask?.cancel()
            if trimmed.isEmpty {
                withAnimation { isSearching = false }
                isSearchLoading = false
                filteredComments = []
                return
            }
            isSearching = true
            isSearchLoading = true
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                await expandCommentsForSearchIfNeeded(maxPasses: 4)
                filteredComments = threadManager.matchingComments(containing: trimmed)
                isSearchLoading = false
            }
        }
        .onSubmit(of: .search) {
            let q = commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return }
            isSearching = true
            isSearchLoading = true
            Task {
                await expandCommentsForSearchIfNeeded(maxPasses: 6)
                await MainActor.run {
                    filteredComments = threadManager.matchingComments(containing: q)
                    isSearchLoading = false
                }
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
        // confirmationDialog removed; Menu handles sorting
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
    
    
    private func commentsSection(proxy: ScrollViewProxy) -> some View {
        Group {
            if (isSearching && isSearchLoading) {
                loadingView
                    .padding(.horizontal, CGFloat(commentHorizontalPadding))
            } else if isSearching {
                if filteredComments.isEmpty {
                    emptyCommentsView
                        .padding(.horizontal, CGFloat(commentHorizontalPadding))
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredComments, id: \.id) { c in
                            CommentView(
                                comment: c,
                                depth: c.depth,
                                post: post,
                                onReplyPosted: { _ in }
                            )
                        }
                    }
                    .padding(.horizontal, CGFloat(commentHorizontalPadding))
                }
            } else if isLoading && threadManager.commentThreads.isEmpty {
                loadingView
                    .padding(.horizontal, CGFloat(commentHorizontalPadding))
            } else if let errorMessage = errorMessage, threadManager.commentThreads.isEmpty {
                errorView(message: errorMessage)
                    .padding(.horizontal, CGFloat(commentHorizontalPadding))
            } else if threadManager.commentThreads.isEmpty {
                emptyCommentsView
                    .padding(.horizontal, CGFloat(commentHorizontalPadding))
            } else {
                commentsListView(proxy: proxy)
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
        }
    
    private func commentsListView(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            let allComments = threadManager.commentThreads.map { $0.parentComment }

            CommentThreadView(
                comments: allComments,
                post: post,
                sort: commentSort,
                scrollProxy: proxy
            )
            .padding(.horizontal, CGFloat(commentHorizontalPadding))

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
                    }
                }
                .padding(.horizontal, CGFloat(commentHorizontalPadding))
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
        .padding(.horizontal, CGFloat(commentHorizontalPadding))
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
        .padding(.horizontal, CGFloat(commentHorizontalPadding))
        .padding(.top, 60)
    }
    
    private var sortButton: some View {
        Menu {
            ForEach(CommentSort.allCases, id: \.self) { sort in
                Button(action: {
                    commentSort = sort
                    Task { await loadComments() }
                }) {
                    HStack(spacing: 8) {
                        if commentSort == sort { Image(systemName: "checkmark") }
                        Image(systemName: sort.iconName)
                        Text(sort.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: commentSort.iconName)
                .font(.callout)
            // Let Liquid Glass handle container styling to avoid double bubble
        }
        .buttonStyle(.plain)
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
                // Prefetch embedded images/GIFs in the just-loaded comments
                MediaPrefetcher.shared.prefetch(comments: comments)
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
            proxy.animatedScrollTo(targetId, anchor: .center)
        }
    }

    // MARK: - Search Expansion
    private func expandCommentsForSearchIfNeeded(maxPasses: Int) async {
        var passes = 0
        while passes < maxPasses {
            passes += 1
            // Prioritize root pagination if available
            if threadManager.hasMoreRootComments, let after = threadManager.rootAfter {
                do {
                    let response = try await redditAPI.fetchPostComments(postId: post.id, sort: commentSort, after: after)
                    if response.count > 1 {
                        let commentsResponse = response[1]
                        let comments = commentsResponse.flattenedComments
                        let nextAfter = commentsResponse.data.after
                        await MainActor.run {
                            threadManager.appendRootPage(newComments: comments, nextAfter: nextAfter)
                        }
                        // Prefetch to keep UI smooth
                        MediaPrefetcher.shared.prefetch(comments: comments)
                        continue
                    }
                } catch {
                    break
                }
            }

            // Otherwise, fetch consolidated root children batch if present
            if let nextMore = threadManager.moreObjects.first {
                do {
                    let batchIds = nextMore.children
                    let newComments = try await redditAPI.fetchMoreComments(postId: post.id, commentIds: batchIds, sort: commentSort)
                    await MainActor.run {
                        if nextMore.name == "root_more_children" {
                            threadManager.appendRootChildrenPage(newComments: newComments, consumedCount: batchIds.count)
                        } else {
                            threadManager.insertMoreComments(newComments, replacingMoreId: nextMore.id)
                        }
                    }
                    MediaPrefetcher.shared.prefetch(comments: newComments)
                    continue
                } catch {
                    break
                }
            }
            // Nothing else to expand
            break
        }
    }
}
