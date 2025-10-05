import SwiftUI
import Defaults

private func canonicalFeedIdentifier(_ value: String) -> String {
    var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasPrefix("/") {
        trimmed.removeFirst()
    }

    var lowercased = trimmed.lowercased()

    if lowercased == "hot" { lowercased = "home" }
    if lowercased == "saved" { lowercased = "user/saved" }

    if lowercased.hasPrefix("u/") {
        lowercased = "user/" + lowercased.dropFirst(2)
    }

    if lowercased.hasPrefix("r/") {
        lowercased.removeFirst(2)
    }

    if lowercased.hasPrefix("user/") {
        let parts = lowercased.split(separator: "/")
        return parts.joined(separator: "/")
    }

    return lowercased
}

private func multiFeedPath(for multi: MultiReddit, username: String?) -> String {
    let user = username?.nilIfEmpty ?? "me"
    return "user/\(user)/m/\(multi.name)"
}

struct SubredditDrawerView: View {
    let apiService: RedditAPIManager
    @State private var subreddits: [Subreddit] = []
    @State private var multis: [MultiReddit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasInitiallyLoaded = false
    @Default(.favoriteSubreddits) private var favoriteSubreddits
    @Default(.defaultHomeFeed) private var defaultHomeFeed
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var showingMultiEditor = false
    @State private var editingMulti: MultiReddit? = nil
    @State private var lastNavigatedDefaultFeed: String? = nil
    @State private var showingDefaultFeedPicker = false
    
    var body: some View {
        Group {
            if isLoading && subreddits.isEmpty {
                loadingViewWithQuickAccess
            } else if let errorMessage = errorMessage, subreddits.isEmpty {
                errorViewWithQuickAccess(errorMessage)
            } else if subreddits.isEmpty {
                emptyStateViewWithQuickAccess
            } else {
                AlphabeticalSubredditList(
                    subreddits: subreddits,
                    onSubredditTap: { subreddit in
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit.displayName))
                    },
                    onQuickLinkTap: { quickLink in
                        let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
                    },
                    multis: multis,
                    onMultiTap: { multi in
                        navigationPath.navigate(to: .subredditFeed(subreddit: multiFeedPath(for: multi, username: apiService.userInfo?.name)))
                    },
                    onCreateMulti: { showingMultiEditor = true },
                    onEditMulti: { m in editingMulti = m },
                    onDeleteMulti: { m in Task { await deleteMulti(m) } },
                    favoriteSubreddits: favoriteSubreddits,
                    onFavoriteToggle: { subreddit in
                        toggleFavorite(subreddit)
                    },
                    subscribedSubreddits: Set(subreddits.map { $0.displayName }),
                    onSubscribeToggle: { subreddit in
                        Task { await unfollow(subreddit) }
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reloadSubreddits() }
        .task {
            if !hasInitiallyLoaded {
                await loadSubredditsInitially()
            }
        }
        .onAppear { navigateToDefaultFeedIfNeeded() }
        .onChange(of: defaultHomeFeed) { _, _ in
            navigateToDefaultFeedIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingDefaultFeedPicker = true
                    } label: {
                        Label("Choose Default Feed", systemImage: "house.fill")
                    }
                    
                    if defaultHomeFeed != nil {
                        Button(role: .destructive) {
                            clearDefaultHomeFeed()
                        } label: {
                            Label("Clear Default Feed", systemImage: "house.slash")
                        }
                    }

                    Divider()

                    Button {
                        showingMultiEditor = true
                    } label: {
                        Label("Create Multireddit", systemImage: "plus.rectangle.on.rectangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More Actions")
            }
        }
        .sheet(isPresented: $showingMultiEditor) {
            MultiEditorView(mode: .create, apiService: apiService, availableSubreddits: subreddits) { created in
                Task { await refreshMultis() }
            }
        }
        .sheet(item: $editingMulti) { m in
            MultiEditorView(mode: .edit(existing: m), apiService: apiService, availableSubreddits: subreddits) { updated in
                Task { await refreshMultis() }
            }
        }
        .sheet(isPresented: $showingDefaultFeedPicker) {
            DefaultFeedPickerView(
                subreddits: subreddits,
                multis: multis,
                favorites: favoriteSubreddits,
                currentSelection: defaultHomeFeed?.nilIfEmpty,
                username: apiService.userInfo?.name
            ) { selection in
                setDefaultHomeFeed(selection)
            }
        }
    }
    
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading communities...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load communities")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await reloadSubreddits() }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 100)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Subscriptions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You haven't subscribed to any communities yet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 100)
    }
    
    private var loadingViewWithQuickAccess: some View {
        List {
            QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id("★")

            Section {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading communities...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func errorViewWithQuickAccess(_ message: String) -> some View {
        List {
            QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id("★")

            Section {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("Failed to load communities")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task { await reloadSubreddits() }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var emptyStateViewWithQuickAccess: some View {
        List {
            QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id("★")

            Section {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(.secondary)
                    
                    Text("No Subscriptions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You haven't subscribed to any communities yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func loadSubredditsInitially() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Try cached first (fast) for both subs and multis, then refresh in background
        do {
            async let cachedSubs = apiService.fetchSubscribedSubredditsCached(forceRefresh: false)
            async let cachedMultis = apiService.fetchUserMultiredditsCached(forceRefresh: false)
            let (subs, ms) = try await (cachedSubs, cachedMultis)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.subreddits = subs.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                    self.multis = ms.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                }
                self.isLoading = false
                self.hasInitiallyLoaded = true
            }
        } catch {
            // Ignore, we'll still try network below
        }

        // Refresh subreddits (only if we didn't have cache) and load multis in parallel
        async let refreshedSubs: [Subreddit]? = self.subreddits.isEmpty ? (try? await apiService.fetchSubscribedSubredditsCached(forceRefresh: true)) : nil
        async let userMultis: [MultiReddit]? = (self.multis.isEmpty) ? (try? await apiService.fetchUserMultiredditsCached(forceRefresh: true)) : nil

        let (subs, ms) = await (refreshedSubs, userMultis)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.18)) {
                if let subs = subs {
                    self.subreddits = subs.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                }
                if let ms = ms {
                    self.multis = ms.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                }
            }
            self.isLoading = false
            self.hasInitiallyLoaded = true
        }
    }

    private func navigateToDefaultFeedIfNeeded() {
        guard navigationPath.path.isEmpty else {
            lastNavigatedDefaultFeed = defaultHomeFeed?.nilIfEmpty.map(canonicalFeedIdentifier)
            return
        }

        guard let target = defaultHomeFeed?.nilIfEmpty else {
            lastNavigatedDefaultFeed = nil
            return
        }

        let canonicalTarget = canonicalFeedIdentifier(target)
        guard lastNavigatedDefaultFeed != canonicalTarget else { return }
        lastNavigatedDefaultFeed = canonicalTarget

        DispatchQueue.main.async {
            navigationPath.navigate(to: .subredditFeed(subreddit: target))
        }
    }

    private func setDefaultHomeFeed(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaultHomeFeed = trimmed
        Task { @MainActor in HapticManager.shared.success() }
    }

    private func clearDefaultHomeFeed() {
        defaultHomeFeed = nil
        lastNavigatedDefaultFeed = nil
        Task { @MainActor in HapticManager.shared.gentleImpact() }
    }

    private func displayName(for value: String) -> String? {
        let canonical = canonicalFeedIdentifier(value)

        switch canonical {
        case "home": return "Home"
        case "popular": return "Popular"
        case "all": return "All"
        case "user/saved": return "Saved"
        default:
            if canonical.contains("/m/") {
                if let match = multis.first(where: { canonicalFeedIdentifier(multiFeedPath(for: $0, username: apiService.userInfo?.name)) == canonical }) {
                    return "m/\(match.name)"
                }
                return canonical
            }

            if let subreddit = subreddits.first(where: { canonicalFeedIdentifier($0.displayName) == canonical }) {
                return subreddit.displayNamePrefixed
            }

            if value.lowercased().hasPrefix("user/") {
                return value
            }

            if value.hasPrefix("r/") {
                return value
            }

            return "r/\(value)"
        }
    }

    @MainActor
    private func refreshMultis() async {
        do {
            let ms = try await apiService.fetchUserMultiredditsCached(forceRefresh: true)
            self.multis = ms.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        } catch {
            // ignore
        }
    }

    private func deleteMulti(_ multi: MultiReddit) async {
        guard let username = apiService.userInfo?.name else { return }
        do {
            try await apiService.deleteMultireddit(username: username, name: multi.name)
            await refreshMultis()
        } catch {
            // ignore for now; could show toast
        }
    }
    
    private func reloadSubreddits() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let fetchedSubreddits = apiService.fetchSubscribedSubredditsCached(forceRefresh: true)
            async let fetchedMultis = apiService.fetchUserMultiredditsCached(forceRefresh: true)
            let (subs, ms) = try await (fetchedSubreddits, fetchedMultis)
            await MainActor.run {
                self.subreddits = subs.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                self.multis = ms.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func toggleFavorite(_ subreddit: Subreddit) {
        let wasRemoved = favoriteSubreddits.contains(subreddit.displayName)
        
        withAnimation(.bouncy(duration: 0.4)) {
            if wasRemoved {
                favoriteSubreddits.remove(subreddit.displayName)
            } else {
                favoriteSubreddits.insert(subreddit.displayName)
            }
        }
        
        // Haptic feedback based on action
        Task { @MainActor in
            if wasRemoved {
                // Gentle haptic for removal
                HapticManager.shared.gentleImpact()
            } else {
                // Success haptic for addition
                HapticManager.shared.success()
            }
        }
    }

    private func unfollow(_ subreddit: Subreddit) async {
        let name = subreddit.displayName
        let previous = subreddits
        await MainActor.run {
            withAnimation(.easeInOut) {
                subreddits.removeAll { $0.displayName == name }
            }
        }

        do {
            try await apiService.unsubscribe(from: name)
        } catch {
            // Revert on failure
            await MainActor.run {
                subreddits = previous
            }
        }
    }
}

private struct DefaultFeedPickerView: View {
    let subreddits: [Subreddit]
    let multis: [MultiReddit]
    let favorites: Set<String>
    let currentSelection: String?
    let username: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var normalizedCurrent: String? {
        currentSelection?.nilIfEmpty.map(canonicalFeedIdentifier)
    }

    private var favoriteCommunities: [Subreddit] {
        subreddits
            .filter { favorites.contains($0.displayName) }
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private var otherCommunities: [Subreddit] {
        subreddits
            .filter { !favorites.contains($0.displayName) }
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private var sortedMultis: [MultiReddit] {
        multis.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Access") {
                    ForEach(QuickLink.allCases, id: \.self) { link in
                        selectionButton(
                            title: link.rawValue,
                            icon: link.iconName,
                            value: quickLinkValue(link)
                        )
                    }
                }

                if !sortedMultis.isEmpty {
                    Section("Multireddits") {
                        ForEach(sortedMultis, id: \.id) { multi in
                            selectionButton(
                                title: "m/\(multi.name)",
                                icon: "rectangle.3.group",
                                value: multiFeedPath(for: multi, username: username)
                            )
                        }
                    }
                }

                if !favoriteCommunities.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteCommunities, id: \.id) { subreddit in
                            selectionButton(
                                title: subreddit.displayNamePrefixed,
                                icon: "star.fill",
                                value: subreddit.displayName
                            )
                        }
                    }
                }

                if !otherCommunities.isEmpty {
                    Section("Subscriptions") {
                        ForEach(otherCommunities, id: \.id) { subreddit in
                            selectionButton(
                                title: subreddit.displayNamePrefixed,
                                icon: "list.bullet",
                                value: subreddit.displayName
                            )
                        }
                    }
                }
            }
            .navigationTitle("Default Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func selectionButton(title: String, icon: String, value: String) -> some View {
        Button {
            onSelect(value)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Label(title, systemImage: icon)
                Spacer()
                if isCurrent(value) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func isCurrent(_ value: String) -> Bool {
        guard let current = normalizedCurrent else { return false }
        return canonicalFeedIdentifier(value) == current
    }

    private func quickLinkValue(_ link: QuickLink) -> String {
        link.endpoint.isEmpty ? "home" : link.endpoint
    }
}

#Preview {
    let apiService = RedditAPIManager()
    apiService.authService.userInfo = RedditUser(
        name: "testuser",
        linkKarma: 1250,
        commentKarma: 8750,
        created: Date().timeIntervalSince1970 - 86400 * 365,
        verified: true,
        hasVerifiedEmail: true
    )
    
    return SubredditDrawerView(apiService: apiService)
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
