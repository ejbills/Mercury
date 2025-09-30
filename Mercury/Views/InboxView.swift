import SwiftUI

struct InboxView: View {
    let apiService: RedditAPIManager
    @State private var messages: [InboxItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var selectedFilter: InboxFilter = .all
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var filterNamespace
    @State private var selectedItem: InboxItem?
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var isRefreshing = false
    
    enum InboxFilter: String, CaseIterable, SectionPickerIconProvider {
        case all = "All"
        case unread = "Unread"
        case messages = "Messages"
        case mentions = "Mentions"
        case replies = "Replies"
        
        var icon: String {
            switch self {
            case .all: return "tray.fill"
            case .unread: return "envelope.badge.fill"
            case .messages: return "message.fill"
            case .mentions: return "at.badge.plus"
            case .replies: return "arrowshape.turn.up.left.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterPickerSection
                
                if isLoading && messages.isEmpty {
                    loadingView
                } else if let errorMessage = errorMessage, messages.isEmpty {
                    errorView(errorMessage)
                } else if messages.isEmpty {
                    emptyStateView
                } else {
                    messagesList
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await reload(preservingData: false) }
        }
        .sheet(item: $selectedItem) { item in
            InboxDetailView(item: item)
                .environment(\.redditAPI, apiService)
        }
        .task { await reload() }
    }
    
    private var filterPickerSection: some View {
        SectionPicker(
            items: InboxFilter.allCases,
            selectedItem: $selectedFilter,
            namespace: filterNamespace,
            accentColor: .accentColor,
            onSelectionChanged: {
                Task { await reload() }
            },
            useBackground: true,
            style: .glass
        )
    }
    
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredMessages) { message in
                    Card(style: .compact) {
                        Button {
                            handleTap(on: message)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                UserAvatar(username: message.author, size: 32)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        if message.isUnread {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 6, height: 6)
                                        }
                                        Text(message.subject)
                                            .font(.headline)
                                            .fontWeight(message.isUnread ? .semibold : .medium)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(message.timeAgo)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("u/\(message.author)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if let subreddit = message.subreddit {
                                            Text("• r/\(subreddit)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Text(message.body)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .onAppear {
                        if message.id == filteredMessages.last?.id && hasMore && !isLoadingMore {
                            Task { await loadMore() }
                        }
                    }
                }
                
                if hasMore {
                    Group {
                        if isLoadingMore {
                            HStack(spacing: 12) {
                                ProgressView().scaleEffect(0.8)
                                Text("Loading more…").font(.body).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                } else if !messages.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("You're up to date").font(.subheadline).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var filteredMessages: [InboxItem] {
        switch selectedFilter {
        case .all:
            return messages
        case .unread:
            return messages.filter { $0.isUnread }
        case .messages:
            return messages.filter { $0.type == .privateMessage }
        case .mentions:
            return messages.filter { $0.type == .mention }
        case .replies:
            return messages.filter { $0.type == .commentReply }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading messages...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load inbox")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await reload() }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Messages")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your inbox is empty. Messages, mentions, and replies will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private func reload(preservingData: Bool = false) async {
        if preservingData {
            await MainActor.run { isRefreshing = true; errorMessage = nil }
            do {
                let page = try await apiService.fetchInbox(category: selectedFilter.apiCategory, limit: 25)
                await MainActor.run {
                    self.messages = page.items
                    self.after = page.after
                    self.hasMore = page.after != nil && !page.items.isEmpty
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run { self.isRefreshing = false }
            }
        } else {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                messages = []
                after = nil
                hasMore = true
            }
            do {
                let page = try await apiService.fetchInbox(category: selectedFilter.apiCategory, limit: 25)
                await MainActor.run {
                    self.messages = page.items
                    self.after = page.after
                    self.hasMore = page.after != nil && !page.items.isEmpty
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
    
    private func loadMore() async {
        guard hasMore, !isLoadingMore, let after else { return }
        await MainActor.run { isLoadingMore = true }
        do {
            let page = try await apiService.fetchInbox(category: selectedFilter.apiCategory, after: after, limit: 25)
            await MainActor.run {
                let newItems = page.items.filter { newItem in
                    !messages.contains { $0.id == newItem.id }
                }
                self.messages.append(contentsOf: newItems)
                self.after = page.after
                self.hasMore = page.after != nil && !newItems.isEmpty
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run { self.isLoadingMore = false }
        }
    }

    // MARK: - Routing
    private func handleTap(on item: InboxItem) {
        switch item.type {
        case .privateMessage:
            selectedItem = item
        case .commentReply, .mention:
            guard let url = item.contextURL else {
                selectedItem = item
                return
            }
            Task {
                if let post = await RedditPostFetchService.shared.fetchPost(from: url.absoluteString) {
                    let commentId = extractCommentId(from: url)
                    await MainActor.run {
                        navigationPath.navigate(to: .postCommentsAnchor(post: post, commentId: commentId))
                    }
                } else {
                    await MainActor.run { selectedItem = item }
                }
            }
        }
    }
    
    private func extractCommentId(from url: URL) -> String? {
        let components = url.pathComponents
        if let commentsIndex = components.firstIndex(of: "comments"), components.count > commentsIndex + 2 {
            let maybeCommentIdIndex = commentsIndex + 3
            if components.count > maybeCommentIdIndex {
                let cid = components[maybeCommentIdIndex]
                if cid.count >= 5 { // naive sanity check
                    return cid
                }
            }
        }
        return nil
    }
}

private extension InboxView.InboxFilter {
    var apiCategory: InboxService.Category {
        switch self {
        case .all: return .all
        case .unread: return .unread
        case .messages: return .messages
        case .mentions: return .mentions
        case .replies: return .replies
        }
    }
}

#Preview {
    InboxView(apiService: RedditAPIManager())
}
