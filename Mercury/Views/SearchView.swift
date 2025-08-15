//
//  SearchView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SearchView: View {
    let apiService: RedditAPIManager
    
    @State private var searchText = ""
    @State private var selectedTab: SearchTab = .posts
    @State private var searchResults: [RedditPost] = []
    @State private var subredditResults: [Subreddit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var mediaNamespace
    @Namespace private var tabSelectionNamespace
    
    enum SearchTab: CaseIterable {
        case posts, subreddits
        
        var title: String {
            switch self {
            case .posts: return "Posts"
            case .subreddits: return "Communities"
            }
        }
        
        var icon: String {
            switch self {
            case .posts: return "doc.text"
            case .subreddits: return "person.2"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                // Tab Picker
                if hasSearched {
                    tabPicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Content
                if isLoading && !hasSearched {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if hasSearched {
                    searchResultsView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search Reddit", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        performSearch()
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            
            if !searchText.isEmpty {
                Button("Search", action: performSearch)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab 
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(tab.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.blue)
                                .matchedGeometryEffect(id: "selectedTab", in: tabSelectionNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                switch selectedTab {
                case .posts:
                    postsResultsView
                case .subreddits:
                    subredditsResultsView
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }
    
    @ViewBuilder
    private var postsResultsView: some View {
        if searchResults.isEmpty && !isLoading {
            Text("No posts found")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            ForEach(searchResults) { post in
                PostRowView(post: post, namespace: mediaNamespace)
                    .onAppear {
                        if post.id == searchResults.last?.id && hasMore && !isLoading {
                            Task {
                                await loadMorePosts()
                            }
                        }
                    }
            }
            
            if hasMore && !searchResults.isEmpty {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more posts...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
    
    @ViewBuilder
    private var subredditsResultsView: some View {
        if subredditResults.isEmpty && !isLoading {
            Text("No communities found")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            MaterialCard {
                VStack(spacing: 0) {
                    ForEach(subredditResults) { subreddit in
                        NavigationLink(destination: SubredditFeedView(subreddit: subreddit.displayName, apiService: apiService)) {
                            SubredditRow(subreddit: subreddit) {}
                        }
                        .buttonStyle(.plain)
                        
                        if subreddit.id != subredditResults.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
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
            
            Text("Search failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 100)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text("Search Reddit")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Find posts, communities, and more")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
            }
            
            VStack(spacing: 16) {
                Text("Popular searches:")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    searchSuggestion("SwiftUI")
                    searchSuggestion("iOS")
                    searchSuggestion("Apple")
                    searchSuggestion("Programming")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }
    
    private func searchSuggestion(_ text: String) -> some View {
        Button(action: {
            searchText = text
            performSearch()
        }) {
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func clearSearch() {
        searchText = ""
        searchResults = []
        subredditResults = []
        hasSearched = false
        errorMessage = nil
        after = nil
        hasMore = true
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                searchResults = []
                subredditResults = []
                after = nil
                hasMore = true
                hasSearched = true
            }
            
            do {
                async let postsTask = apiService.searchPosts(query: searchText, limit: 25)
                async let subredditsTask = apiService.searchSubreddits(query: searchText, limit: 25)
                
                let (postsResponse, subreddits) = try await (postsTask, subredditsTask)
                
                await MainActor.run {
                    self.searchResults = postsResponse.data.children.compactMap { $0.data }
                    self.subredditResults = subreddits
                    self.after = postsResponse.data.after
                    self.hasMore = postsResponse.data.after != nil && !self.searchResults.isEmpty
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
    
    private func loadMorePosts() async {
        guard hasMore && !isLoading && after != nil && selectedTab == .posts else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let response = try await apiService.searchPosts(query: searchText, after: after, limit: 25)
            await MainActor.run {
                let newPosts = response.data.children.compactMap { $0.data }
                
                let uniqueNewPosts = newPosts.filter { newPost in
                    !searchResults.contains { existingPost in
                        existingPost.id == newPost.id
                    }
                }
                
                self.searchResults.append(contentsOf: uniqueNewPosts)
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    let apiService = RedditAPIManager()
    return SearchView(apiService: apiService)
}
