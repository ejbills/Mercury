import SwiftUI
import Defaults

struct SubredditDrawerView: View {
    let apiService: RedditAPIManager
    @State private var subreddits: [Subreddit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasInitiallyLoaded = false
    @Default(.favoriteSubreddits) private var favoriteSubreddits
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var searchText: String = ""
    
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
                    subreddits: filteredSubreddits,
                    onSubredditTap: { subreddit in
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit.displayName))
                    },
                    onQuickLinkTap: { quickLink in
                        let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
                    },
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
        .navigationBarHidden(true)
        .refreshable { await reloadSubreddits() }
        .task { 
            if !hasInitiallyLoaded {
                await loadSubredditsInitially()
            }
        }
        .searchable(text: $searchText)
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
            Section(header: quickAccessSectionHeader) {
                QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                    let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                    navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
                }
                .listRowSeparator(.hidden)
            }
            
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
            Section(header: quickAccessSectionHeader) {
                QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                    let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                    navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
                }
                .listRowSeparator(.hidden)
            }
            
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
            Section(header: quickAccessSectionHeader) {
                QuickAccessGrid(quickLinks: QuickLink.allCases) { quickLink in
                    let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                    navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
                }
                .listRowSeparator(.hidden)
            }
            
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
    
    private var quickAccessSectionHeader: some View {
        HStack {
            Pill(size: .regular) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("Quick Access")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    
    private func loadSubredditsInitially() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            subreddits = []
        }
        
        do {
            let fetchedSubreddits = try await apiService.fetchSubscribedSubreddits()
            await MainActor.run {
                self.subreddits = fetchedSubreddits.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                self.isLoading = false
                self.hasInitiallyLoaded = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func reloadSubreddits() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            subreddits = []
        }
        
        do {
            let fetchedSubreddits = try await apiService.fetchSubscribedSubreddits()
            await MainActor.run {
                self.subreddits = fetchedSubreddits.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
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

private extension SubredditDrawerView {
    var filteredSubreddits: [Subreddit] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return subreddits }
        return subreddits.filter { s in
            s.displayName.localizedCaseInsensitiveContains(q) ||
            s.title.localizedCaseInsensitiveContains(q) ||
            s.publicDescription.localizedCaseInsensitiveContains(q)
        }
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
