//
//  MainTabView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct MainTabView: View {
    let apiService: RedditAPIManager
    @State private var homeNavigationPath = NavigationPathManager()
    @State private var inboxNavigationPath = NavigationPathManager()
    @State private var searchNavigationPath = NavigationPathManager()
    @State private var profileNavigationPath = NavigationPathManager()
    @State private var settingsNavigationPath = NavigationPathManager()
    
    var body: some View {
        TabView {
            // Home Tab (Communities)
            NavigationStack(path: $homeNavigationPath.path) {
                SubredditDrawerView(apiService: apiService)
                    .environment(\.navigationPathManager, homeNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: homeNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            // Inbox Tab
            NavigationStack(path: $inboxNavigationPath.path) {
                InboxView(apiService: apiService)
                    .environment(\.navigationPathManager, inboxNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: inboxNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "envelope.fill")
                Text("Inbox")
            }
            
            // Profile Tab (center)
            NavigationStack(path: $profileNavigationPath.path) {
                Group {
                    if let username = apiService.userInfo?.name, !username.isEmpty {
                        UserProfileView(username: username)
                    } else {
                        // Fallback if not authenticated
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Sign in to view your profile")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Add your Reddit Client ID and finish setup to continue.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .navigationTitle("Profile")
                    }
                }
                .environment(\.navigationPathManager, profileNavigationPath)
                .environment(\.redditAPI, apiService)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    navigationDestination(for: destination, navigationPath: profileNavigationPath)
                }
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }

            // Search Tab (moved right of Profile)
            NavigationStack(path: $searchNavigationPath.path) {
                SearchView(apiService: apiService)
                    .environment(\.navigationPathManager, searchNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: searchNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }

            // Settings Tab (far right)
            NavigationStack(path: $settingsNavigationPath.path) {
                SettingsView(apiService: apiService)
                    .environment(\.navigationPathManager, settingsNavigationPath)
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
        }
        .tint(Color.accentColor)
    }
    
    @ViewBuilder
    private func navigationDestination(for destination: NavigationDestination, navigationPath: NavigationPathManager) -> some View {
        switch destination {
        case .subredditFeed(let subreddit):
            SubredditFeedView(subreddit: subreddit, apiService: apiService)
                .environment(\.navigationPathManager, navigationPath)
        case .userProfile(let username):
            UserProfileView(username: username)
                .environment(\.redditAPI, apiService)
                .environment(\.navigationPathManager, navigationPath)
        case .postDetail(let post):
            MediaDetailView(post: post, namespace: Namespace().wrappedValue)
                .environment(\.navigationPathManager, navigationPath)
        case .postComments(let post):
            PostCommentsView(post: post)
                .environment(\.redditAPI, apiService)
                .environment(\.navigationPathManager, navigationPath)
        case .postCommentsAnchor(let post, let commentId):
            PostCommentsView(post: post, targetCommentId: commentId)
                .environment(\.redditAPI, apiService)
                .environment(\.navigationPathManager, navigationPath)
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
    
    return MainTabView(apiService: apiService)
}
