//
//  MainTabView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct MainTabView: View {
    let apiService: RedditAPIService
    
    var body: some View {
        TabView {
            // Home Feed Tab
            SubredditFeedView(subreddit: "popular", apiService: apiService)
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            // Communities (Subreddit Drawer)
            SubredditDrawerView(apiService: apiService)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Communities")
                }
            
            // Search Tab
            NavigationView {
                VStack {
                    Text("Search")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Coming Soon")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Search")
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            
            // Profile Tab
            NavigationView {
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
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
        }
        .tint(Color.accentColor)
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
    
    return MainTabView(apiService: apiService)
}