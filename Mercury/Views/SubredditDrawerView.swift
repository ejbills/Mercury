import SwiftUI

struct SubredditDrawerView: View {
    let apiService: RedditAPIManager
    @State private var subreddits: [Subreddit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasInitiallyLoaded = false
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        Group {
            if isLoading && subreddits.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage, subreddits.isEmpty {
                errorView(errorMessage)
            } else if subreddits.isEmpty {
                emptyStateView
            } else {
                AlphabeticalSubredditList(
                    subreddits: subreddits,
                    onSubredditTap: { subreddit in
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit.displayName))
                    },
                    onQuickLinkTap: { quickLink in
                        let subreddit = quickLink.endpoint.isEmpty ? "home" : quickLink.endpoint
                        navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
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
