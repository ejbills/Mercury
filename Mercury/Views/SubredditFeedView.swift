//
//  SubredditFeedView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SubredditFeedView: View {
    let subreddit: String
    let apiService: RedditAPIManager
    @State private var posts: [RedditPost] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var mediaNamespace
    @State private var scrollPosition: String?
    @State private var hasAppeared = false
    @State private var selectedPost: RedditPost?
    
    private let pageSize = 25
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if posts.isEmpty && isLoading {
                        skeletonLoadingView
                    } else if posts.isEmpty && errorMessage != nil {
                        errorView
                            .padding(.top, 100)
                    } else if posts.isEmpty {
                        emptyStateView
                            .padding(.top, 100)
                    } else {
                        ForEach(posts) { post in
                            PostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                                .id(post.id) // Important for scroll position tracking
                                .onAppear {
                                    if post.id == posts.last?.id && hasMore && !isLoadingMore {
                                        Task {
                                            await loadMorePosts()
                                        }
                                    }
                                }
                        }
                        
                        if hasMore {
                            loadMoreSection
                        } else {
                            endOfFeedView
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
            .scrollPosition(id: $scrollPosition)
            .onAppear {
                // Only load initial posts if we haven't appeared before and have no posts
                if !hasAppeared && posts.isEmpty && !isLoading {
                    hasAppeared = true
                    Task {
                        await loadInitialPosts()
                    }
                }
            }
        }
        .navigationTitle(subredditDisplayName)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $selectedPost) { post in
            PostDetailRouter(post: post, namespace: mediaNamespace)
        }
        .refreshable {
            await refreshFeed()
        }
    }
    
    private var subredditDisplayName: String {
        if subreddit == "popular" {
            return "Popular"
        } else if subreddit == "all" {
            return "All"
        } else if subreddit.hasPrefix("r/") {
            return subreddit
        } else {
            return "r/\(subreddit)"
        }
    }
    
    private var loadMoreSection: some View {
        Group {
            if isLoadingMore {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading more posts...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        if hasMore && !isLoadingMore {
                            Task {
                                await loadMorePosts()
                            }
                        }
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
                // Remove animation for initial load to prevent layout jumping
                self.posts = response.data.children.compactMap { $0.data }
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !response.data.children.isEmpty
                self.isLoading = false
            }
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
                
                self.posts.append(contentsOf: uniqueNewPosts)
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
            }
            // Failed to load more posts
        }
    }
    
    private func refreshFeed() async {
        // Don't restore position on refresh - user expects to go to top
        await loadInitialPosts()
    }
    
    private func fetchPosts(after: String?) async throws -> PostResponse {
        switch subreddit.lowercased() {
        case "popular":
            return try await apiService.fetchPopularFeed(after: after, limit: pageSize)
        case "home", "hot":
            return try await apiService.fetchHomeFeed(after: after, limit: pageSize)
        default:
            let cleanSubreddit = subreddit.hasPrefix("r/") ? String(subreddit.dropFirst(2)) : subreddit
            return try await apiService.fetchSubredditPosts(subreddit: cleanSubreddit, after: after, limit: pageSize)
        }
    }
}
