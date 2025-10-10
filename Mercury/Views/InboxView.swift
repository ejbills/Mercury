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
    @State private var hasLoaded = false
    
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
                    .padding(.bottom, 8)

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All Read") {
                            Task { await markAllReadForCurrentFilter() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .refreshable { await reload(preservingData: false) }
        }
        .sheet(item: $selectedItem) { item in
            InboxDetailView(item: item)
                .environment(\.redditAPI, apiService)
        }
        .task {
            if !hasLoaded {
                await reload()
                hasLoaded = true
            }
        }
    }
    
    private func markAllReadForCurrentFilter() async {
        // Map UI filter to service category and perform server-side mark all
        let category: InboxService.Category = {
            switch selectedFilter {
            case .all: return .all
            case .unread: return .unread
            case .messages: return .messages
            case .mentions: return .mentions
            case .replies: return .replies
            }
        }()

        do {
            try await apiService.markAllInboxRead(for: category)
        } catch {
            // Ignore errors for now; could surface an alert if desired
        }

        // Optimistically update locally-loaded items of the selected type
        await MainActor.run {
            messages = messages.map { item in
                let shouldMark: Bool = {
                    switch selectedFilter {
                    case .all, .unread: return true
                    case .messages: return item.type == .privateMessage
                    case .mentions: return item.type == .mention
                    case .replies: return item.type == .commentReply
                    }
                }()
                if shouldMark {
                    return InboxItem(
                        id: item.id,
                        fullName: item.fullName,
                        subject: item.subject,
                        body: item.body,
                        author: item.author,
                        subreddit: item.subreddit,
                        isUnread: false,
                        created: item.created,
                        type: item.type,
                        contextURL: item.contextURL
                    )
                } else { return item }
            }
        }
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
        List {
            ForEach(filteredMessages) { message in
                Card(style: .compact) {
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await handleTapAndMarkRead(on: message) }
                    }
                }
                .padding(.horizontal, 12)
                .feedListRowStyle()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await deleteMessageItem(message) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await toggleReadStatus(for: message) }
                    } label: {
                        Label(message.isUnread ? "Read" : "Unread", systemImage: message.isUnread ? "envelope.open" : "envelope.badge")
                    }
                    .tint(message.isUnread ? .blue : .orange)
                }
                .onAppear {
                    if message.id == filteredMessages.last?.id && hasMore && !isLoadingMore {
                        Task { await loadMore() }
                    }
                }
            }
            
            if hasMore {
                if isLoadingMore {
                    HStack(spacing: 12) {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading more…").font(.body).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .feedListRowStyle()
                } else {
                    Color.clear
                        .frame(height: 1)
                        .feedListRowStyle()
                }
            } else if !messages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("You're up to date").font(.subheadline).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .feedListRowStyle()
            }
        }
        .feedListBaseStyle(rowSpacing: 8)
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
            await MainActor.run { errorMessage = nil }
            do {
                let page = try await apiService.fetchInbox(category: selectedFilter.apiCategory, limit: 25)
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        self.messages = page.items
                    }
                    self.after = page.after
                    self.hasMore = page.after != nil && !page.items.isEmpty
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
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
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        self.messages = page.items
                    }
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    self.messages.append(contentsOf: newItems)
                }
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
    
    private func markRead(fullnames: [String]) async {
        do { try await apiService.markMessagesRead(fullnames: fullnames) } catch { }
    }

    private func handleTapAndMarkRead(on item: InboxItem) async {
        await MainActor.run { handleTap(on: item) }
        guard item.isUnread, let fullname = item.fullName else { return }
        await markRead(fullnames: [fullname])
        await MainActor.run {
            if let idx = messages.firstIndex(where: { $0.id == item.id }) {
                messages[idx] = InboxItem(
                    id: item.id,
                    fullName: item.fullName,
                    subject: item.subject,
                    body: item.body,
                    author: item.author,
                    subreddit: item.subreddit,
                    isUnread: false,
                    created: item.created,
                    type: item.type,
                    contextURL: item.contextURL
                )
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

    // MARK: - Swipe Actions

    private func deleteMessageItem(_ item: InboxItem) async {
        guard let fullname = item.fullName else { return }

        // Optimistically remove from UI
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                messages.removeAll { $0.id == item.id }
            }
        }

        do {
            try await apiService.deleteMessage(fullname: fullname)
        } catch {
            // On failure, restore the item
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    messages.append(item)
                    messages.sort { $0.created > $1.created }
                }
            }
        }
    }

    private func toggleReadStatus(for item: InboxItem) async {
        guard let fullname = item.fullName else { return }

        let newReadState = !item.isUnread

        // Optimistically update UI
        await MainActor.run {
            if let idx = messages.firstIndex(where: { $0.id == item.id }) {
                messages[idx] = InboxItem(
                    id: item.id,
                    fullName: item.fullName,
                    subject: item.subject,
                    body: item.body,
                    author: item.author,
                    subreddit: item.subreddit,
                    isUnread: newReadState,
                    created: item.created,
                    type: item.type,
                    contextURL: item.contextURL
                )
            }
        }

        do {
            if newReadState {
                try await apiService.markMessagesUnread(fullnames: [fullname])
            } else {
                try await apiService.markMessagesRead(fullnames: [fullname])
            }
        } catch {
            // On failure, revert the change
            await MainActor.run {
                if let idx = messages.firstIndex(where: { $0.id == item.id }) {
                    messages[idx] = item
                }
            }
        }
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
