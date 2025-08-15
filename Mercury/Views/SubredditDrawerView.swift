//
//  SubredditDrawerView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SubredditDrawerView: View {
    let apiService: RedditAPIManager
    @State private var subreddits: [Subreddit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                quickLinksSection
                    .padding(.bottom, 24)
                
                subscribedSubredditsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("Communities")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadSubreddits()
        }
        .task {
            await loadSubreddits()
        }
    }
    
    
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "star.fill", title: "Quick Access")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(QuickLink.allCases, id: \.self) { link in
                    quickLinkCard(for: link)
                }
            }
        }
    }
    
    private func quickLinkCard(for link: QuickLink) -> some View {
        Button(action: {
            let subreddit = link.endpoint.isEmpty ? "popular" : link.endpoint
            navigationPath.navigate(to: .subredditFeed(subreddit: subreddit))
        }) {
            VStack(spacing: 12) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(iconGradient(for: link))
                        .frame(width: 50, height: 50)
                        .shadow(color: shadowColor(for: link), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: link.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                // Title
                Text(link.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func iconGradient(for link: QuickLink) -> LinearGradient {
        switch link {
        case .home:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .popular:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .all:
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .saved:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func shadowColor(for link: QuickLink) -> Color {
        switch link {
        case .home:
            return .blue.opacity(0.3)
        case .popular:
            return .orange.opacity(0.3)
        case .all:
            return .purple.opacity(0.3)
        case .saved:
            return .green.opacity(0.3)
        }
    }
    
    private var subscribedSubredditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                icon: "person.2.fill",
                title: "Subscribed (\(subreddits.count))",
                color: .blue
            )
            
            MaterialCard {
                Group {
                    if isLoading {
                        loadingView
                    } else if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    } else if subreddits.isEmpty {
                        emptyStateView
                    } else {
                        subredditList
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading subreddits...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            
            Text("Failed to load subreddits")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadSubreddits()
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Subscriptions")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You haven't subscribed to any subreddits yet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var subredditList: some View {
        VStack(spacing: 0) {
            ForEach(subreddits.prefix(50)) { subreddit in
                SubredditRow(subreddit: subreddit) {
                    navigationPath.navigate(to: .subredditFeed(subreddit: subreddit.displayName))
                }
                
                if subreddit.id != subreddits.prefix(50).last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
            
            if subreddits.count > 50 {
                Button("Show All (\(subreddits.count))") {
                    // Show full subreddit list
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 16)
            }
        }
    }
    
    private func loadSubreddits() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
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