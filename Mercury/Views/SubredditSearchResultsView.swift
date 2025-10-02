import SwiftUI

struct SubredditSearchResultsView: View {
    let subreddit: String
    let apiService: RedditAPIManager
    let query: String

    @State private var posts: [RedditPost] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var mediaNamespace
    @State private var selectedPost: RedditPost?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if posts.isEmpty && isLoading {
                        ProgressView().padding(.top, 80)
                    } else if let errorMessage, posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Search failed").font(.headline)
                            Text(errorMessage).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Try Again") { Task { await loadInitial() } }.buttonStyle(.bordered)
                        }.padding(.top, 60)
                    } else if posts.isEmpty {
                        Text("No results").foregroundStyle(.secondary).padding(.top, 80)
                    } else {
                        ForEach(posts) { post in
                            PostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                                .onAppear {
                                    if post.id == posts.last?.id && hasMore && !isLoading {
                                        Task { await loadMore() }
                                    }
                                }
                        }
                        if hasMore && isLoading {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Loading more…").foregroundStyle(.secondary)
                            }.padding(.vertical, 20)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .navigationTitle("r/\(subreddit) • \(query)")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadInitial() }
            .fullScreenCover(item: $selectedPost) { post in
                MediaDetailView(post: post, namespace: mediaNamespace)
            }
        }
    }

    private func loadInitial() async {
        await MainActor.run { isLoading = true; errorMessage = nil; posts = []; after = nil; hasMore = true }
        do {
            let res = try await apiService.searchPosts(query: query, subreddit: subreddit, after: nil, limit: 25, sort: "relevance", timeFrame: nil)
            await MainActor.run {
                self.posts = res.data.children.compactMap { $0.data }
                self.after = res.data.after
                self.hasMore = res.data.after != nil && !self.posts.isEmpty
                self.isLoading = false
            }
            MediaPrefetcher.shared.prefetch(posts: self.posts)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
        }
    }

    private func loadMore() async {
        guard hasMore, let after else { return }
        await MainActor.run { isLoading = true }
        do {
            let res = try await apiService.searchPosts(query: query, subreddit: subreddit, after: after, limit: 25, sort: "relevance", timeFrame: nil)
            await MainActor.run {
                let new = res.data.children.compactMap { $0.data }
                let unique = new.filter { n in !posts.contains(where: { $0.id == n.id }) }
                self.posts.append(contentsOf: unique)
                self.after = res.data.after
                self.hasMore = res.data.after != nil && !unique.isEmpty
                self.isLoading = false
            }
            MediaPrefetcher.shared.prefetch(posts: self.posts)
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
}

