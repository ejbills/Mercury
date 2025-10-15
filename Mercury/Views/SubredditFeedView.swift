import SwiftUI
import Defaults
import Combine

struct SubredditFeedView: View {
    let subreddit: String
    let apiService: RedditAPIManager
    @Environment(\.navigationPathManager) private var navigationPathManager
    @State private var posts: [RedditPost] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var after: String?
    @State private var hasMore = true
    @Default(.defaultPostSort) private var postSort
    @State private var topTimeFrame: TopTimeFrame = .day
    // Old confirmation dialogs replaced by anchored Menus
    @Namespace private var mediaNamespace
    @State private var scrollPosition: String?
    @State private var hasAppeared = false
    @State private var selectedPost: RedditPost?
    @State private var videoHandoffState: VideoHandoffState?
    @Default(.postLayoutStyle) private var postLayoutStyle
    @Default(.hiddenPostIds) private var hiddenPostIds
    @State private var showSidebar = false
    @State private var hasSidebar: Bool = false
    @State private var feedSearchText: String = ""
    @State private var isSearching = false
    @State private var searchResults: [RedditPost] = []
    @State private var searchAfter: String? = nil
    @State private var isSearchLoading = false
    @State private var searchHasMore = true
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var showingPostComposer = false
    
    private let pageSize = 25
    @Default(.feedItemSpacing) private var feedItemSpacing
    @Default(.feedBackgroundStyle) private var feedBackgroundStyle
    @Default(.customFeedBackgroundColor) private var customFeedBackgroundColor
    @Default(.postHorizontalPadding) private var postHorizontalPadding
    
    
    var body: some View {
        let base = isSearching ? searchResults : posts

        return ScrollView {
            LazyVStack(spacing: CGFloat(feedItemSpacing)) {
                if (isSearching ? searchResults.isEmpty : posts.isEmpty) && (isSearching ? isSearchLoading : isLoading) {
                    skeletonLoadingView
                        .padding(.horizontal, CGFloat(postHorizontalPadding))
                } else if !isSearching && posts.isEmpty && errorMessage != nil && !isLoading {
                    errorView
                        .padding(.horizontal, CGFloat(postHorizontalPadding))
                        .padding(.top, 100)
                } else if (!isSearching && posts.isEmpty) || (isSearching && searchResults.isEmpty && !isSearchLoading) {
                    emptyStateView
                        .padding(.horizontal, CGFloat(postHorizontalPadding))
                        .padding(.top, 100)
                } else {
                    ForEach(base) { post in
                        if !hiddenPostIds.contains(post.id) {
                            Group {
                                if postLayoutStyle == .compact {
                                    CompactPostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                                } else {
                                    PostRowView(
                                        post: post,
                                        namespace: mediaNamespace,
                                        selectedPost: $selectedPost,
                                        onVideoHandoff: { handoffState in
                                            videoHandoffState = handoffState
                                        },
                                        onHidePost: { id in
                                            hiddenPostIds.insert(id)
                                        },
                                        onHidePostsAbove: { id in
                                            if let index = posts.firstIndex(where: { $0.id == id }) {
                                                let ids = posts.prefix(index).map { $0.id }
                                                hiddenPostIds.formUnion(ids)
                                                let nextVisibleId = posts.first { !hiddenPostIds.contains($0.id) }?.id
                                                scrollToTop(targetId: nextVisibleId)
                                            }
                                        }
                                    )
                                }
                            }
                            .id(post.id)
                            .onAppear {
                                // Find the last visible post to handle cases where many posts are hidden
                                let lastVisiblePost = isSearching
                                    ? searchResults.last(where: { !hiddenPostIds.contains($0.id) })
                                    : posts.last(where: { !hiddenPostIds.contains($0.id) })

                                if isSearching {
                                    if post.id == lastVisiblePost?.id && searchHasMore && !isSearchLoading {
                                        Task { await loadMoreSearch() }
                                    }
                                } else if post.id == lastVisiblePost?.id && hasMore && !isLoadingMore {
                                    Task { await loadMorePosts() }
                                }
                            }
                        }
                    }

                    if isSearching {
                        if isSearchLoading && !searchResults.isEmpty {
                            loadingFooter(text: "Loading more results…")
                                .padding(.horizontal, CGFloat(postHorizontalPadding))
                        } else if !searchHasMore && !searchResults.isEmpty {
                            endOfFeedView
                                .padding(.horizontal, CGFloat(postHorizontalPadding))
                        }
                    } else {
                        if isLoadingMore {
                            loadingFooter(text: "Loading more posts…")
                                .padding(.horizontal, CGFloat(postHorizontalPadding))
                        } else if !hasMore {
                            endOfFeedView
                                .padding(.horizontal, CGFloat(postHorizontalPadding))
                        }
                    }
                }
            }
        }
        .feedBackground(style: feedBackgroundStyle, customColor: customFeedBackgroundColor?.color)
        .scrollPosition(id: $scrollPosition)
        .onAppear {
            if !hasAppeared && posts.isEmpty {
                hasAppeared = true
                Task {
                    await loadInitialPosts()
                    await preloadSidebarFlag()
                }
            }
        }
        .navigationTitle(subredditDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $feedSearchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search \(subredditDisplayName)")
        .onChange(of: feedSearchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            searchDebounceTask?.cancel()
            if trimmed.isEmpty {
                withAnimation { isSearching = false }
                return
            }
            isSearching = true
            isSearchLoading = true
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                await performInFeedSearch(reset: true)
            }
        }
        .onSubmit(of: .search) {
            Task { await performInFeedSearch(reset: true) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortButton
            }
            // Show sidebar button only for real subreddits and when sidebar exists
            ToolbarItem(placement: .navigationBarTrailing) {
                if isRealSubreddit && hasSidebar {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasSidebar)
                    .accessibilityLabel("Subreddit Sidebar")
                }
            }
            // Create Post button available from any feed; composer handles subreddit entry
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingPostComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New Post")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mercuryAccountDidSwitch)) { _ in
            Task { await handleAccountSwitch() }
        }
        .fullScreenCover(item: $selectedPost) { post in
            PostDetailContainer(
                post: post,
                namespace: mediaNamespace,
                videoHandoffState: $videoHandoffState,
                onDismiss: {
                    selectedPost = nil
                }
            )
        }
        .refreshable {
            await refreshFeed()
        }
        .sheet(isPresented: $showSidebar) {
            SubredditSidebarView(subreddit: subreddit, apiService: apiService)
        }
        .sheet(isPresented: $showingPostComposer) {
            PostComposerSheet(initialSubreddit: isRealSubreddit ? subredditDisplayName : "") {
                Task { await refreshFeed() }
            }
            .environment(\.redditAPI, apiService)
        }
        // confirmationDialogs removed; Menu anchored to toolbar button handles sorting
    }

    private var subredditDisplayName: String {
        if subreddit == "popular" {
            return "Popular"
        } else if subreddit == "all" || subreddit == "r/all" {
            return "All"
        } else if subreddit == "user/saved" || subreddit == "saved" {
            return "Saved"
        } else if subreddit.lowercased().contains("/m/") && (subreddit.hasPrefix("user/") || subreddit.hasPrefix("u/")) {
            // Show m/<name> for multireddits
            let comps = subreddit.split(separator: "/").map(String.init)
            if let mIndex = comps.firstIndex(of: "m"), mIndex + 1 < comps.count {
                return "m/\(comps[mIndex + 1])"
            }
            return subreddit
        } else if subreddit.hasPrefix("r/") {
            return subreddit
        } else {
            return "r/\(subreddit)"
        }
    }

    private var isRealSubreddit: Bool {
        let s = subreddit.lowercased()
        if s == "popular" || s == "all" || s == "user/saved" || s == "saved" || s == "home" || s == "hot" { return false }
        if s.contains("/m/") { return false }
        return true
    }

    private func preloadSidebarFlag() async {
        guard isRealSubreddit else { return }
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        do {
            let about = try await apiService.fetchSubredditAbout(subreddit: clean)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.hasSidebar = !about.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !about.publicDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    self.hasSidebar = false
                }
            }
        }
    }
    
    private var endOfFeedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
            
            Text("You've reached the end!")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("That's all the posts for now.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var skeletonLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadingFooter(text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func scrollToTop(targetId: String?) {
        withAnimation(.snappy(duration: 0.2)) {
            scrollPosition = targetId
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if scrollPosition == targetId {
                scrollPosition = nil
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load posts")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task {
                    await loadInitialPosts()
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Posts Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This subreddit doesn't have any posts or they're not accessible.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var sortButton: some View {
        Menu {
            // Sort options
            ForEach(PostSort.allCases, id: \.self) { sort in
                Button(action: {
                    postSort = sort
                    Task { await loadInitialPosts() }
                }) {
                    HStack(spacing: 8) {
                        if postSort == sort { Image(systemName: "checkmark") }
                        Image(systemName: sort.iconName)
                        Text(sort.displayName)
                    }
                }
            }
            
            if postSort.supportsTimeFrame {
                Divider()
                Menu("Time Frame") {
                    ForEach(TopTimeFrame.allCases, id: \.self) { time in
                        Button(action: {
                            topTimeFrame = time
                            Task { await loadInitialPosts() }
                        }) {
                            HStack(spacing: 8) {
                                if topTimeFrame == time { Image(systemName: "checkmark") }
                                Image(systemName: time.iconName)
                                Text(time.displayName)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: postSort.iconName)
                .font(.callout)
            // Let Liquid Glass handle container styling to avoid double bubble
        }
        .buttonStyle(.plain)
    }

    private func loadInitialPosts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            posts = []
            after = nil
            hasMore = true
        }
        
        do {
            let response = try await fetchPosts(after: nil)
            await MainActor.run {
                self.posts = response.data.children.compactMap { $0.data }
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !response.data.children.isEmpty
                self.isLoading = false
            }
            // Eagerly prefetch media for the loaded posts
            MediaPrefetcher.shared.prefetch(posts: self.posts)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadMorePosts() async {
        guard hasMore && !isLoadingMore && after != nil else { return }

        await MainActor.run {
            isLoadingMore = true
        }

        do {
            let response = try await fetchPosts(after: after)
            await MainActor.run {
                let newPosts = response.data.children.compactMap { $0.data }
                
                let uniqueNewPosts = newPosts.filter { newPost in
                    !posts.contains { existingPost in
                        existingPost.id == newPost.id
                    }
                }
                
                if !uniqueNewPosts.isEmpty {
                    self.posts.append(contentsOf: uniqueNewPosts)
                }
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.isLoadingMore = false
            }
            // Prefetch media for newly appended posts
            MediaPrefetcher.shared.prefetch(posts: self.posts)
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
            }
        }
    }
    
    private func refreshFeed() async {
        await MainActor.run {
            errorMessage = nil
            after = nil
            hasMore = true
        }

        do {
            let response = try await fetchPosts(after: nil)
            let newPosts = response.data.children.compactMap { $0.data }
            await MainActor.run {
                self.posts = newPosts
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.errorMessage = nil // Clear any previous error on success
            }
            MediaPrefetcher.shared.prefetch(posts: self.posts)
        } catch {
            if Task.isCancelled { return }
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func handleAccountSwitch() async {
        await MainActor.run {
            searchDebounceTask?.cancel()
            searchDebounceTask = nil
            feedSearchText = ""
            isSearching = false
            isSearchLoading = false
            searchResults = []
            searchAfter = nil
            searchHasMore = true
            errorMessage = nil
            scrollPosition = nil
            videoHandoffState = nil
            posts = []
            after = nil
            hasMore = true
            isLoading = false
            isLoadingMore = false
            selectedPost = nil
        }
        await loadInitialPosts()
    }

    // MARK: - In-feed Search
    @MainActor
    private func performInFeedSearch(reset: Bool) async {
        let clean = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
        let query = feedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            isSearching = false
            isSearchLoading = false
            return
        }
        if reset {
            searchAfter = nil
            searchHasMore = true
            searchResults = []
        }
        do {
            let res = try await apiService.searchPosts(query: query, subreddit: clean, after: searchAfter, limit: pageSize, sort: "relevance", timeFrame: nil)
            let new = res.data.children.compactMap { $0.data }
            let unique = new.filter { n in !searchResults.contains(where: { $0.id == n.id }) }

            let currentAnchor = scrollPosition
            if !unique.isEmpty {
                searchResults.append(contentsOf: unique)
            }
            searchAfter = res.data.after
            searchHasMore = res.data.after != nil && !unique.isEmpty
            isSearchLoading = false
            if let currentAnchor {
                scrollPosition = currentAnchor
            }

            MediaPrefetcher.shared.prefetch(posts: self.searchResults)
        } catch {
            isSearchLoading = false
        }
    }

    private func loadMoreSearch() async {
        guard isSearching, searchHasMore, !isSearchLoading else { return }
        isSearchLoading = true
        await performInFeedSearch(reset: false)
    }

    private func fetchPosts(after: String?) async throws -> PostResponse {
        let s = subreddit.lowercased()
        switch s {
        case "popular":
            return try await apiService.fetchPopularFeed(after: after, limit: pageSize)
        case "home", "hot":
            let timeFrame = postSort.supportsTimeFrame ? topTimeFrame : nil
            return try await apiService.fetchHomeFeed(sort: postSort, timeFrame: timeFrame, after: after, limit: pageSize)
        case "user/saved", "saved":
            return try await apiService.fetchSavedPosts(after: after, limit: pageSize)
        default:
            // Multireddit path: user/<username>/m/<multi>
            if s.contains("/m/") {
                let comps = subreddit.split(separator: "/").map(String.init)
                if let userIndex = comps.firstIndex(where: { $0 == "user" || $0 == "u" }),
                   userIndex + 1 < comps.count,
                   let mIndex = comps.firstIndex(of: "m"),
                   mIndex + 1 < comps.count {
                    let username = comps[userIndex + 1]
                    let multiName = comps[mIndex + 1]
                    let timeFrame = postSort.supportsTimeFrame ? topTimeFrame : nil
                    return try await apiService.fetchMultiPosts(username: username, multi: multiName, sort: postSort, timeFrame: timeFrame, after: after, limit: pageSize)
                }
            }
            let cleanSubreddit = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
            let timeFrame = postSort.supportsTimeFrame ? topTimeFrame : nil
            return try await apiService.fetchSubredditPosts(subreddit: cleanSubreddit, sort: postSort, timeFrame: timeFrame, after: after, limit: pageSize)
        }
    }
    
}
