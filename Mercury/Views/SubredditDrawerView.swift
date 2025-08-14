//
//  SubredditDrawerView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SubredditDrawerView: View {
    let apiService: RedditAPIService
    @State private var subreddits: [Subreddit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let userInfo = apiService.userInfo {
                        userHeader(userInfo)
                            .padding(.bottom, 20)
                    }
                    
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
    }
    
    private func userHeader(_ user: RedditUser) -> some View {
        MaterialCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 44, height: 44)
                    
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("u/\(user.name)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(user.totalKarma.formatted()) karma")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "star.fill", title: "Quick Links")
            
            MaterialCard {
                VStack(spacing: 0) {
                    ForEach(QuickLink.allCases, id: \.self) { link in
                        NavigationLink(destination: SubredditFeedView(subreddit: link.endpoint.isEmpty ? "popular" : link.endpoint, apiService: apiService)) {
                            QuickLinkRow(quickLink: link) {}
                        }
                        .buttonStyle(.plain)
                        
                        if link != QuickLink.allCases.last {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
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
                NavigationLink(destination: SubredditFeedView(subreddit: subreddit.displayName, apiService: apiService)) {
                    SubredditRow(subreddit: subreddit) {}
                }
                .buttonStyle(.plain)
                
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
    let apiService = RedditAPIService()
    apiService.userInfo = RedditUser(
        name: "testuser",
        linkKarma: 1250,
        commentKarma: 8750,
        created: Date().timeIntervalSince1970 - 86400 * 365,
        verified: true,
        hasVerifiedEmail: true
    )
    
    return SubredditDrawerView(apiService: apiService)
}