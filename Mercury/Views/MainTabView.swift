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
    @State private var communitiesNavigationPath = NavigationPathManager()
    @State private var searchNavigationPath = NavigationPathManager()
    @State private var profileNavigationPath = NavigationPathManager()
    
    var body: some View {
        TabView {
            // Home Feed Tab
            NavigationStack(path: $homeNavigationPath.path) {
                SubredditFeedView(subreddit: "popular", apiService: apiService)
                    .environment(\.navigationPathManager,homeNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: homeNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            // Communities (Subreddit Drawer)
            NavigationStack(path: $communitiesNavigationPath.path) {
                SubredditDrawerView(apiService: apiService)
                    .environment(\.navigationPathManager,communitiesNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: communitiesNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "person.2.fill")
                Text("Communities")
            }
            
            // Search Tab
            NavigationStack(path: $searchNavigationPath.path) {
                SearchView(apiService: apiService)
                    .environment(\.navigationPathManager,searchNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: searchNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            
            // Profile Tab
            NavigationStack(path: $profileNavigationPath.path) {
                VStack(spacing: 24) {
                    if let userInfo = apiService.userInfo {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.gradient)
                                    .frame(width: 80, height: 80)
                                
                                Text(String(userInfo.name.prefix(1)).uppercased())
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("u/\(userInfo.name)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(userInfo.totalKarma.formatted()) karma")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        SecondaryButton(
                            "Sign Out",
                            icon: "rectangle.portrait.and.arrow.right"
                        ) {
                            apiService.clearStoredCredentials()
                        }
                        .padding(.horizontal, 20)
                        
                        Text("Mercury v1.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 40)
                }
                .navigationTitle("Profile")
                    .environment(\.navigationPathManager,profileNavigationPath)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestination(for: destination, navigationPath: profileNavigationPath)
                    }
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
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