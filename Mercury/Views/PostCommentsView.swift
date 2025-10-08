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
    @State private var postVoteState: RedditPost.VoteState
    @State private var postDisplayScore: Int
    @State private var postIsVoting: Bool = false
    @State private var postSavedState: Bool
    @State private var showingPostReply = false
    @State private var shareItem: URL?
    @State private var shareItems: [URL]?
    @State private var showShareSheet = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @Default(.postHorizontalPadding) private var postHorizontalPadding
    @Default(.feedBackgroundStyle) private var feedBackgroundStyle
    @Default(.customFeedBackgroundColor) private var customFeedBackgroundColor
    @Default(.commentHorizontalPadding) private var commentHorizontalPadding
    @Default(.postLayoutStyle) private var postLayoutStyle
    @Default(.postNormalShowActions) private var postNormalShowActions
    @Default(.postNormalShowScore) private var postNormalShowScore
    @Default(.postNormalShowCommentCount) private var postNormalShowCommentCount
    @Default(.postNormalShowVoting) private var postNormalShowVoting
    @Default(.postCompactShowActions) private var postCompactShowActions
    @Default(.postCompactShowScore) private var postCompactShowScore
    @Default(.postCompactShowCommentCount) private var postCompactShowCommentCount
    @Default(.postCompactShowVoting) private var postCompactShowVoting

        init(post: RedditPost, targetCommentId: String? = nil) {
            self.post = post
            self.targetCommentId = targetCommentId
            self._postVoteState = State(initialValue: post.currentVoteState)
            self._postDisplayScore = State(initialValue: post.displayScore)
            self._postSavedState = State(initialValue: post.saved)
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
                            .overlay {
                                if isDownloading && (post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery) {
                                    downloadProgressOverlay
                                }
                            }

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
                        .overlay {
                            if isDownloading && (post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery) {
                                downloadProgressOverlay
                            }
                        }
                    }

                    // Post Action Toolbar
                    if (postLayoutStyle == .normal && postNormalShowActions) || (postLayoutStyle == .compact && postCompactShowActions) {
                        PostActionToolbar(
                            post: post,
                            voteState: $postVoteState,
                            displayScore: $postDisplayScore,
                            isVoting: $postIsVoting,
                            savedState: $postSavedState,
                            onVote: handlePostVote,
                            onReply: { showingPostReply = true },
                            onShare: handlePostShare,
                            onSave: handlePostSave,
                            onCopyLink: handlePostCopyLink,
                            onOpenOriginal: handlePostOpenOriginal,
                            onDownload: handlePostDownload,
                            colorScheme: .light,
                            size: .large,
                            showScore: postLayoutStyle == .normal ? postNormalShowScore : postCompactShowScore,
                            showCommentCount: postLayoutStyle == .normal ? postNormalShowCommentCount : postCompactShowCommentCount,
                            showVoting: postLayoutStyle == .normal ? postNormalShowVoting : postCompactShowVoting
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
        .sheet(isPresented: $showingPostReply) {
            MarkdownComposerView(
                title: "Reply",
                accounts: redditAPI.availableAccountUsernames(),
                activeAccount: redditAPI.userInfo?.name ?? redditAPI.activeUsername,
                onCancel: { showingPostReply = false },
                onSubmit: { text, account in
                    try await submitPostReply(text: text, account: account)
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let urls = shareItems {
                MediaShareSheet(post: post, mediaURLs: urls)
            } else {
                MediaShareSheet(post: post, mediaURL: shareItem)
            }
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

    // MARK: - Post Action Handlers

    private func handlePostVote(_ newVoteState: RedditPost.VoteState) {
        guard !postIsVoting else { return }

        let originalState = postVoteState
        let originalScore = postDisplayScore

        withAnimation(.bouncy(duration: 0.4)) {
            let scoreDelta = calculateScoreDelta(from: postVoteState, to: newVoteState)
            postVoteState = newVoteState
            postDisplayScore = max(0, postDisplayScore + scoreDelta)
        }

        postIsVoting = true

        Task {
            do {
                let voteDirection: VoteDirection = switch newVoteState {
                case .upvoted: .upvote
                case .downvoted: .downvote
                case .neutral: .neutral
                }

                try await redditAPI.voteOnPost(postId: post.id, voteDirection: voteDirection)

                await MainActor.run {
                    postIsVoting = false
                }
            } catch {
                await MainActor.run {
                    withAnimation(.bouncy(duration: 0.4)) {
                        postVoteState = originalState
                        postDisplayScore = originalScore
                    }
                    postIsVoting = false
                }
            }
        }
    }

    private func calculateScoreDelta(from oldState: RedditPost.VoteState, to newState: RedditPost.VoteState) -> Int {
        switch (oldState, newState) {
        case (.neutral, .upvoted): return 1
        case (.neutral, .downvoted): return -1
        case (.upvoted, .neutral): return -1
        case (.upvoted, .downvoted): return -2
        case (.downvoted, .neutral): return 1
        case (.downvoted, .upvoted): return 2
        default: return 0
        }
    }

    private func handlePostShare() {
        shareItem = nil
        showShareSheet = true
    }

    private func handlePostSave() {
        Task {
            let originalState = postSavedState
            await MainActor.run {
                postSavedState.toggle()
            }

            do {
                if originalState {
                    try await redditAPI.unsavePost(postId: post.id)
                } else {
                    try await redditAPI.savePost(postId: post.id)
                }
            } catch {
                print("Save/Unsave error: \(error)")
                await MainActor.run {
                    postSavedState = originalState
                }
            }
        }
    }

    private func handlePostCopyLink() {
        UIPasteboard.general.string = post.permalinkURL

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func handlePostOpenOriginal() {
        if let urlString = post.url, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func submitPostReply(text: String, account: String) async throws {
        let parent = post.fullname
        let created = try await redditAPI.performUsingAccount(username: account) {
            try await redditAPI.submitComment(parentFullname: parent, text: text)
        }
        await MainActor.run {
            threadManager.addRootComment(created)
        }
    }

    private func handlePostDownload() {
        guard post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery else { return }
        guard !isDownloading else { return }
        isDownloading = true
        Task {
            defer { isDownloading = false }
            do {
                let service = MediaDownloadService()
                if post.postType == .gallery {
                    let urls = try await service.downloadAllGalleryImages(post: post, options: .init(
                        preferredFilename: post.id,
                        onProgress: { progress in
                            Task { @MainActor in
                                downloadProgress = progress
                            }
                        }
                    ))
                    await MainActor.run {
                        shareItems = urls
                        shareItem = nil
                        showShareSheet = true
                    }
                } else {
                    let fileURL = try await service.download(post: post, options: .init(
                        preferredFilename: post.id,
                        onProgress: { progress in
                            Task { @MainActor in
                                downloadProgress = progress
                            }
                        }
                    ))
                    await MainActor.run {
                        shareItem = fileURL
                        shareItems = nil
                        showShareSheet = true
                    }
                }
            } catch {
                // On failure, do not present share sheet
            }
        }
    }

    @ViewBuilder
    private var downloadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)

                VStack(spacing: 4) {
                    let downloadText = switch post.postType {
                    case .video: "Downloading Video"
                    case .youtube: "Opening YouTube"
                    case .gif: "Downloading GIF"
                    case .image: "Downloading Image"
                    case .gallery: "Downloading Gallery"
                    default: "Downloading"
                    }

                    Text(downloadText)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(Int(downloadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloadProgress)
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
