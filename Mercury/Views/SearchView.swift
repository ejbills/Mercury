import SwiftUI
import Defaults

struct SearchView: View {
    let apiService: RedditAPIManager
    
    // Search text supports both legacy internal state and iOS 26 external binding
    @Binding private var searchTextExternal: String
    private let usesExternalSearchText: Bool
    @State private var searchTextInternal: String = ""
    private var searchText: Binding<String> { usesExternalSearchText ? $searchTextExternal : $searchTextInternal }
    @Default(.defaultSearchTab) private var selectedTab
    @Default(.defaultSearchSort) private var selectedSort
    @State private var searchResults: [RedditPost] = []
    @State private var subredditResults: [Subreddit] = []
    @State private var userResults: [UserProfile] = []
    @State private var subscribedSubreddits: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var after: String?
    @State private var hasMore = true
    // Old confirmation dialogs replaced by anchored Menus in the toolbar
    @State private var isDebouncing = false
    @Namespace private var mediaNamespace
    @Namespace private var tabSelectionNamespace
    @Namespace private var sortNamespace
    @State private var selectedPost: RedditPost?
    @Environment(\.navigationPathManager) private var navigationPath
    @FocusState private var isSearchFocused: Bool
    @Default(.feedItemSpacing) private var feedItemSpacing
    @Default(.postHorizontalPadding) private var postHorizontalPadding
    @Default(.feedBackgroundStyle) private var feedBackgroundStyle
    @Default(.customFeedBackgroundColor) private var customFeedBackgroundColor
    @Default(.postLayoutStyle) private var postLayoutStyle
    
    @State private var debounceTask: Task<Void, Never>? = nil
    
    // MARK: - Initializers
    private let initialScopeSubreddit: String?

    init(apiService: RedditAPIManager, initialScopeSubreddit: String? = nil) {
        self.apiService = apiService
        self._searchTextExternal = .constant("")
        self.usesExternalSearchText = false
        self.initialScopeSubreddit = initialScopeSubreddit
    }

    init(apiService: RedditAPIManager, searchText: Binding<String>) {
        self.apiService = apiService
        self._searchTextExternal = searchText
        self.usesExternalSearchText = true
        self._searchTextInternal = State(initialValue: searchText.wrappedValue)
        self.initialScopeSubreddit = nil
    }
    
    enum SearchTab: String, CaseIterable, Codable, Defaults.Serializable, SectionPickerIconProvider {
        case posts = "Posts"
        case subreddits = "Communities"
        case users = "Users"
        
        var icon: String {
            switch self {
            case .posts: return "doc.text.fill"
            case .subreddits: return "person.2.fill"
            case .users: return "person.fill"
            }
        }
    }
    
    enum SearchSort: String, CaseIterable, Codable, Defaults.Serializable, SectionPickerIconProvider {
        case relevance = "Relevance"
        case new = "New"
        case hot = "Hot"
        case top = "Top"
        
        var icon: String {
            switch self {
            case .relevance: return "target"
            case .new: return "clock.fill"
            case .hot: return "flame.fill"
            case .top: return "arrow.up.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header area
            Group {
        if #available(iOS 26.0, *) {
            // No local search UI or section header — toolbar hosts segmented control.
            EmptyView()
        } else {
            VStack(spacing: 8) {
                searchBar
                    .padding(.horizontal, 16)

                        // Removed subreddit scope pill for simpler search UX

                        SectionPicker(
                            items: SearchTab.allCases,
                            selectedItem: $selectedTab,
                            namespace: tabSelectionNamespace,
                            accentColor: .accentColor,
                            onSelectionChanged: {
                                isSearchFocused = true
                            },
                            useBackground: false
                        )
                        .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                    }
                    .background(.regularMaterial)
                }
            }
            
            if isDebouncing && !hasSearched {
                debounceLoadingView
            } else if isLoading && !hasSearched {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if hasSearched {
                searchResultsView
            } else {
                emptyStateView
            }
        }
        .feedBackground(style: feedBackgroundStyle, customColor: customFeedBackgroundColor?.color)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .fullScreenCover(item: $selectedPost) { post in
            MediaDetailView(post: post, namespace: mediaNamespace)
        }
        .onAppear {
            loadSubscribedSubreddits()
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
        }
        // React to system/legacy search text changes
        .onChange(of: searchText.wrappedValue) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            debounceTask?.cancel()
            if trimmed.isEmpty {
                isDebouncing = false
            } else {
                isDebouncing = true
                debounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if Task.isCancelled { return }
                    performSearch()
                }
            }
        }
        .onSubmit(of: .search) {
            debounceTask?.cancel()
            debounceTask = nil
            performSearch()
        }
        
        // confirmationDialogs removed; Menus are anchored to toolbar items
    }

    private var navTitle: String {
        if #available(iOS 26.0, *) { return "Search" }
        return ""
    }
    
    // Deprecated: old header removed to unify with app style
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search posts, communities, users...", text: searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isSearchFocused)
                .onSubmit {
                    performSearch()
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.wrappedValue.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
    }
    
    
    @ViewBuilder
    private var searchResultsView: some View {
        List {
            switch selectedTab {
            case .posts:
                postsResultsView
            case .subreddits:
                subredditsResultsView
            case .users:
                usersResultsView
            }
        }
        .feedListBaseStyle(rowSpacing: CGFloat(feedItemSpacing))
        .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
    }
    
    @ViewBuilder
    private var postsResultsView: some View {
        if searchResults.isEmpty && !isLoading {
            Text("No posts found")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
        } else {
            ForEach(searchResults) { post in
                    Group {
                        if postLayoutStyle == .compact {
                            CompactPostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                        } else {
                            PostRowView(
                                post: post, 
                                namespace: mediaNamespace, 
                                selectedPost: $selectedPost
                            )
                        }
                    }
                    .feedListRowStyle()
                    .onAppear {
                        if post.id == searchResults.last?.id && hasMore && !isLoading {
                            Task {
                                await loadMorePosts()
                            }
                        }
                    }
            }
            
            if hasMore && !searchResults.isEmpty {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more posts...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
            }
        }
    }
    
    @ViewBuilder
    private var subredditsResultsView: some View {
        if subredditResults.isEmpty && !isLoading {
            Text("No communities found")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
        } else {
            ForEach(Array(subredditResults.enumerated()), id: \.1.id) { _, subreddit in
                SubredditRow(
                    subreddit: subreddit,
                    action: {
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit.displayName))
                    },
                    isFavorite: false,
                    onFavoriteToggle: nil,
                    isSubscribed: subscribedSubreddits.contains(subreddit.displayName),
                    onSubscribeToggle: { Task { await toggleSubscription(for: subreddit) } }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var debounceLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
        .transition(.opacity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Search failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 100)
    }
    
    @ViewBuilder
    private var usersResultsView: some View {
        if userResults.isEmpty && !isLoading {
            Text("No users found")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
        } else {
            ForEach(Array(userResults.enumerated()), id: \.1.id) { _, user in
                UserRowView(user: user) {
                    navigationPath.navigate(to: .userProfile(username: user.actualName))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, CGFloat(postHorizontalPadding))
                .feedListRowStyle()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("Search Reddit")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Find posts, communities, and more")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 80)
        .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // iOS 26+: host the Posts/Communities/Users switch as a dropdown button
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: { selectedTab = .posts }) {
                        HStack(spacing: 8) {
                            if selectedTab == .posts { Image(systemName: "checkmark") }
                            Label("Posts", systemImage: SearchTab.posts.icon)
                        }
                    }
                    Button(action: { selectedTab = .subreddits }) {
                        HStack(spacing: 8) {
                            if selectedTab == .subreddits { Image(systemName: "checkmark") }
                            Label("Communities", systemImage: SearchTab.subreddits.icon)
                        }
                    }
                    Button(action: { selectedTab = .users }) {
                        HStack(spacing: 8) {
                            if selectedTab == .users { Image(systemName: "checkmark") }
                            Label("Users", systemImage: SearchTab.users.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(selectedTab.rawValue)
                            .font(.callout)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    // Let Liquid Glass handle container styling
                }
                .buttonStyle(.plain)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(SearchSort.allCases, id: \.self) { sort in
                    Button(action: { applySort(sort) }) {
                        HStack(spacing: 8) {
                            if selectedSort == sort { Image(systemName: "checkmark") }
                            Image(systemName: sort.icon)
                            Text(sort.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: selectedSort.icon)
                    .font(.callout)
                // Let Liquid Glass handle container styling
            }
            .buttonStyle(.plain)
            .disabled(selectedTab != .posts)
        }
    }

    @MainActor
    private func applySort(_ sort: SearchSort) {
        selectedSort = sort
        if hasSearched { performSearch() }
    }
    
    // MARK: - Actions
    
    private func clearSearch() {
        searchText.wrappedValue = ""
        searchResults = []
        subredditResults = []
        userResults = []
        hasSearched = false
        errorMessage = nil
        after = nil
        hasMore = true
    }
    
    private func performSearch() {
        let query = searchText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        Task {
            await MainActor.run {
                isDebouncing = false
                isLoading = true
                errorMessage = nil
                searchResults = []
                subredditResults = []
                after = nil
                hasMore = true
                hasSearched = true
                }

            do {
                async let postsTask = searchPosts()
                async let subredditsTask = apiService.searchSubreddits(query: query, limit: 25)
                async let usersTask = searchUsers()
                
                let (postsResponse, subreddits, users) = try await (postsTask, subredditsTask, usersTask)
                
                await MainActor.run {
                    self.searchResults = postsResponse.data.children.compactMap { $0.data }
                    self.subredditResults = subreddits
                    self.userResults = users
                    self.after = postsResponse.data.after
                    self.hasMore = postsResponse.data.after != nil && !self.searchResults.isEmpty
                    self.isLoading = false
                    }
                MediaPrefetcher.shared.prefetch(posts: self.searchResults)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    }
            }
        }
    }
    
    private func loadMorePosts() async {
        guard hasMore && !isLoading && after != nil && selectedTab == .posts else { return }
        
        await MainActor.run {
            isLoading = true
            }
        
        do {
            let response = try await searchPosts(after: after)
            await MainActor.run {
                let newPosts = response.data.children.compactMap { $0.data }
                
                let uniqueNewPosts = newPosts.filter { newPost in
                    !searchResults.contains { existingPost in
                        existingPost.id == newPost.id
                    }
                }
                
                self.searchResults.append(contentsOf: uniqueNewPosts)
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.isLoading = false
                }
            MediaPrefetcher.shared.prefetch(posts: self.searchResults)
        } catch {
            await MainActor.run {
                self.isLoading = false
                }
        }
    }
    
    // MARK: - Helper Methods
    
    // Combine-based debounce removed in favor of Task-based approach above.
    
    private func loadSubscribedSubreddits() {
        Task {
            do {
                let subreddits = try await apiService.fetchSubscribedSubreddits()
                await MainActor.run {
                    self.subscribedSubreddits = Set(subreddits.map { $0.displayName })
                }
            } catch {
                // Ignore failure to pre-load subscriptions
            }
        }
    }
    
    private func searchPosts(after: String? = nil) async throws -> PostResponse {
        let sortParam: String
        switch selectedSort {
        case .relevance: sortParam = "relevance"
        case .new: sortParam = "new"
        case .hot: sortParam = "hot"
        case .top: sortParam = "top"
        }

        return try await apiService.searchPosts(
            query: searchText.wrappedValue,
            after: after,
            limit: 25,
            sort: sortParam,
            timeFrame: nil
        )
    }
    
    private func searchUsers() async throws -> [UserProfile] {
        let keywords = searchText.wrappedValue.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var users: [UserProfile] = []
        
        for keyword in keywords.prefix(3) {
            do {
                let user = try await apiService.fetchUserProfile(username: keyword)
                users.append(user)
            } catch {
                continue
            }
        }
        
        return users
    }
    
    private func toggleSubscription(for subreddit: Subreddit) async {
        let name = subreddit.displayName
        let isCurrentlySubscribed = subscribedSubreddits.contains(name)

        // Optimistic UI update
        await MainActor.run {
            if isCurrentlySubscribed { subscribedSubreddits.remove(name) }
            else { subscribedSubreddits.insert(name) }
        }

        do {
            if isCurrentlySubscribed {
                try await apiService.unsubscribe(from: name)
            } else {
                try await apiService.subscribe(to: name)
            }
        } catch {
            // Revert on failure
            await MainActor.run {
                if isCurrentlySubscribed { subscribedSubreddits.insert(name) }
                else { subscribedSubreddits.remove(name) }
            }
        }
    }

    // Removed subreddit scope parsing for simpler search UX
}

// Removed custom SubredditRowView in favor of shared Components/Lists/SubredditRow

struct UserRowView: View {
    let user: UserProfile
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: user.effectiveIconImg ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.orange.opacity(0.2))
                        .overlay {
                            Text(String((user.actualName.first?.uppercased()) ?? "U"))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("u/\(user.actualName)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if user.isGold == true {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        if user.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(user.totalKarma.formatted()) karma")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let created = user.created {
                            Text("Joined \(formatJoinDate(created))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatJoinDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
