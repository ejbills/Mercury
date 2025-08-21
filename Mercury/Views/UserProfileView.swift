import SwiftUI
import NukeUI

struct UserProfileView: View {
    let username: String
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    @State private var profile: UserProfile?
    @State private var posts: [RedditPost] = []
    @State private var comments: [RedditComment] = []
    @State private var postsAfter: String?
    @State private var commentsAfter: String?
    @State private var isLoading = false
    @State private var isLoadingMorePosts = false
    @State private var isLoadingMoreComments = false
    @State private var errorMessage: String?
    @Namespace private var mediaNamespace
    @State private var selectedPost: RedditPost?
    @State private var showCompose = false
    @State private var commentPostMap: [String: RedditPost] = [:]
    @State private var commentsContextReady = false
    @State private var headerAvatarURL: URL? = nil
    
    @State private var videoHandoffState: VideoHandoffState?
    @State private var selectedSection: ProfileSection = .posts
    
    enum ProfileSection: String, CaseIterable {
        case posts = "Posts"
        case comments = "Comments"
        case about = "About"
        
        var icon: String {
            switch self {
            case .posts: return "doc.text.fill"
            case .comments: return "bubble.left.fill"
            case .about: return "person.fill"
            }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                header
                segmentPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                switch selectedSection {
                case .posts:
                    postsList
                case .comments:
                    commentsList
                case .about:
                    aboutSection
                }
            }
            .refreshable { await refreshAll() }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task { await initialLoad() }
        .fullScreenCover(item: $selectedPost) { post in
            MediaDetailView(
                post: post,
                namespace: mediaNamespace,
                videoHandoffState: videoHandoffState,
                onVideoHandoffReturn: { returnedState in
                    videoHandoffState = returnedState
                    selectedPost = nil
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showCompose = true } label: { Image(systemName: "bubble.right") }
                    .accessibilityLabel("Chat")
                Button { shareProfile() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share profile")
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeMessageSheet(toUsername: username, isPresented: $showCompose)
                .environment(\.redditAPI, redditAPI)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [accentColor.opacity(0.35), accentColor.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 220)
                .overlay(alignment: .topTrailing) {
                    Circle().fill(accentColor.opacity(0.12)).frame(width: 160)
                        .offset(x: 40, y: -40)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle().fill(accentColor.opacity(0.12)).frame(width: 220)
                        .offset(x: -60, y: 60)
                }
            
            HStack(alignment: .center, spacing: 16) {
                avatar
                VStack(alignment: .leading, spacing: 6) {
                    Text("u/\(username)")
                        .font(.system(size: 28, weight: .bold))
                    if let profile {
                        HStack(spacing: 10) {
                            labelChip(system: "arrow.up.circle.fill", text: "\(profile.totalKarma.formatted()) karma")
                            if let cake = profile.created { labelChip(system: "gift.fill", text: cakeDayText(cake)) }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(height: 220)
        .clipped()
        .overlay(Divider(), alignment: .bottom)
    }
    
    private var avatar: some View {
        Group {
            if let url = profile?.profileIconURL ?? headerAvatarURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else if state.isLoading {
                        ZStack {
                            Circle().fill(accentColor.opacity(0.2))
                            ProgressView().progressViewStyle(.circular)
                        }
                    } else {
                        ZStack { Circle().fill(accentColor); Text(initials).font(.title).bold().foregroundStyle(.white) }
                    }
                }
            } else if isLoading {
                ZStack {
                    Circle().fill(accentColor.opacity(0.2))
                    ProgressView().progressViewStyle(.circular)
                }
            } else {
                ZStack { Circle().fill(accentColor); Text(initials).font(.title).bold().foregroundStyle(.white) }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
        .shadow(color: accentColor.opacity(0.2), radius: 6, x: 0, y: 2)
    }
    
    private func labelChip(system: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
            Text(text)
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private func cakeDayText(_ createdUTC: Double) -> String {
        let date = Date(timeIntervalSince1970: createdUTC)
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
    
    private var initials: String { String(username.prefix(1)).uppercased() }
    
    private var accentColor: Color {
        let colors: [Color] = [.orange, .pink, .purple, .blue, .teal, .mint, .indigo]
        return colors[abs(username.hashValue) % colors.count]
    }
    
    private var segmentPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileSection.allCases, id: \.self) { s in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedSection = s }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(s.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(selectedSection == s ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selectedSection == s {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.blue)
                                    .matchedGeometryEffect(id: "selectedSectionTab", in: mediaNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    
    // MARK: - Posts
    private var postsList: some View {
        Group {
            if isLoading && posts.isEmpty {
                loadingState(text: "Loading posts…")
            } else if let errorMessage, posts.isEmpty {
                errorState(message: errorMessage) { Task { await refreshAll() } }
            } else if posts.isEmpty {
                emptyState(title: "No Posts", message: "This user hasn't posted yet.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(posts) { post in
                        PostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                            .onAppear {
                                if post.id == posts.last?.id { Task { await loadMorePostsIfNeeded() } }
                            }
                    }
                    if isLoadingMorePosts { progressRow(text: "Loading more…") }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Comments
    private var commentsList: some View {
        Group {
            if isLoading && comments.isEmpty {
                loadingState(text: "Loading comments…")
            } else if let errorMessage, comments.isEmpty {
                errorState(message: errorMessage) { Task { await refreshAll() } }
            } else if comments.isEmpty {
                emptyState(title: "No Comments", message: "This user hasn't commented yet.")
            } else if !commentsContextReady {
                loadingState(text: "Preparing comments…")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(comments, id: \.self) { comment in
                        if let key = linkKey(for: comment), let post = commentPostMap[key] ?? commentPostMap[stripT3(key)] {
                                CommentView(comment: comment, depth: 0, post: post) { } onReplyPosted: { _ in }
                                    .allowsHitTesting(false)
                                    .environment(\.redditAPI, redditAPI)
                                    .environment(\.navigationPathManager, navigationPath)
                                    .onTapGesture {
                                        navigationPath.navigate(to: .postComments(post: post))
                                    }
                        }
                        Color.clear.frame(height: 1)
                            .onAppear { if comment.id == comments.last?.id { Task { await loadMoreCommentsIfNeeded() } } }
                    }
                    if isLoadingMoreComments { progressRow(text: "Loading more…") }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - About
    private var aboutSection: some View {
        Group {
            if let profile {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("About")
                    infoRow(label: "Username", value: "u/\(profile.actualName)")
                    infoRow(label: "Total Karma", value: profile.totalKarma.formatted())
                    infoRow(label: "Link Karma", value: (profile.linkKarma ?? 0).formatted())
                    infoRow(label: "Comment Karma", value: (profile.commentKarma ?? 0).formatted())
                    if let created = profile.created { infoRow(label: "Cake Day", value: cakeDayText(created)) }
                    infoRow(label: "Verified", value: (profile.verified ?? false) ? "Yes" : "No")
                    infoRow(label: "Email Verified", value: (profile.hasVerifiedEmail ?? false) ? "Yes" : "No")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            } else {
                loadingState(text: "Loading profile…")
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.headline)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.body)
        .padding(.vertical, 8)
        .overlay(Divider().offset(y: 16), alignment: .bottom)
    }
    
    // MARK: - States
    private func loadingState(text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
    
    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 36, weight: .regular)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
    
    private func errorState(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Failed to load").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try Again", action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
    
    private func progressRow(text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - Data
    private func initialLoad() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let p = redditAPI.fetchUserProfile(username: username)
            async let postsResp = redditAPI.fetchUserPosts(username: username, after: nil, limit: 25)
            async let commentsResp = redditAPI.fetchUserComments(username: username, after: nil, limit: 25)
            
            let (profile, postsResponse, commentsResponse) = try await (p, postsResp, commentsResp)
            let enrichedPosts = postsResponse.data.children.compactMap { $0.data }
            let enrichedComments = commentsResponse.data.children.compactMap { child in
                if case .comment(let c) = child.data { return c } else { return nil }
            }

            let derivedAvatarURL: URL? = (
                enrichedPosts.first(where: { $0.authorIconURL != nil })?.authorIconURL ??
                enrichedComments.first(where: { $0.authorIconURL != nil })?.authorIconURL
            )

            await MainActor.run {
                self.profile = profile
                self.posts = enrichedPosts
                self.postsAfter = postsResponse.data.after
                self.comments = enrichedComments
                self.commentsAfter = commentsResponse.data.after
                if self.headerAvatarURL == nil, profile.profileIconURL == nil, let d = derivedAvatarURL {
                    self.headerAvatarURL = d
                }
            }
            if await MainActor.run(body: { self.headerAvatarURL }) == nil && profile.profileIconURL == nil {
                if let fetched = await redditAPI.fetchAvatarURL(username: username) {
                    await MainActor.run { self.headerAvatarURL = fetched }
                }
            }
            await ensurePostsForComments(comments)
            await MainActor.run { commentsContextReady = true }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
    
    private func refreshAll() async {
        posts = []
        comments = []
        postsAfter = nil
        commentsAfter = nil
        await initialLoad()
    }
    
    private func loadMorePostsIfNeeded() async {
        guard !isLoadingMorePosts, let after = postsAfter else { return }
        isLoadingMorePosts = true
        defer { isLoadingMorePosts = false }
        do {
            let response = try await redditAPI.fetchUserPosts(username: username, after: after, limit: 25)
            await MainActor.run {
                let newPosts = response.data.children.compactMap { $0.data }
                let unique = newPosts.filter { np in !posts.contains(where: { $0.id == np.id }) }
                posts.append(contentsOf: unique)
                postsAfter = response.data.after
            }
        } catch { }
    }
    
    private func loadMoreCommentsIfNeeded() async {
        guard !isLoadingMoreComments, let after = commentsAfter else { return }
        isLoadingMoreComments = true
        defer { isLoadingMoreComments = false }
        do {
            let response = try await redditAPI.fetchUserComments(username: username, after: after, limit: 25)
            let new = response.data.children.compactMap { child -> RedditComment? in
                if case .comment(let c) = child.data { return c } else { return nil }
            }
            let unique = new.filter { nc in !comments.contains(where: { $0.id == nc.id }) }
            await ensurePostsForComments(unique)
            await MainActor.run {
                comments.append(contentsOf: unique)
                commentsAfter = response.data.after
            }
        } catch { }
    }
    
    private func ensurePostsForComments(_ comments: [RedditComment]) async {
        let needed = Set(comments.compactMap { linkKey(for: $0) }).filter { key in
            commentPostMap[key] == nil && commentPostMap[stripT3(key)] == nil
        }
        guard !needed.isEmpty else { return }
        do {
            let posts = try await redditAPI.fetchPostsByFullnames(Array(needed))
            var map = commentPostMap
            for p in posts {
                map["t3_\(p.id)"] = p
                map[p.id] = p
            }
            await MainActor.run { self.commentPostMap = map }
        } catch { }
    }
    
    private func linkKey(for comment: RedditComment) -> String? {
        if let linkId = comment.linkId, !linkId.isEmpty { return linkId }
        let parts = comment.permalink.split(separator: "/")
        if let idx = parts.firstIndex(of: Substring("comments")), parts.count > idx + 1 {
            let postId = String(parts[idx + 1])
            return "t3_\(postId)"
        }
        return nil
    }
    
    private func stripT3(_ key: String) -> String { key.hasPrefix("t3_") ? String(key.dropFirst(3)) : key }
    
    private func shareProfile() {
        let profileURL = URL(string: "https://reddit.com/u/\(username)")!
        let vc = UIActivityViewController(activityItems: [profileURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let window = scene.windows.first {
            window.rootViewController?.present(vc, animated: true)
        }
    }
    
    private struct CommentFallbackRow: View {
        let comment: RedditComment
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(comment.subreddit.map { "r/\($0)" } ?? "Comment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(comment.timeAgo).font(.caption).foregroundStyle(.secondary)
                }
                MarkdownRenderer(content: comment.body, compactMode: true, showEmbeddedContent: false)
                    .font(.body)
                HStack { Spacer() }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private struct ComposeMessageSheet: View {
        let toUsername: String
        @Binding var isPresented: Bool
        @Environment(\.redditAPI) private var redditAPI
        @State private var subject: String = ""
        @State private var bodyText: String = ""
        @State private var selectedRange: NSRange = .init(location: 0, length: 0)
        @State private var isFirstResponder: Bool = true
        @State private var isSending = false
        @State private var error: String?
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 12) {
                    HStack {
                        Text("To")
                        Spacer()
                        Text("u/\(toUsername)").foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    
                    HStack(spacing: 8) {
                        Text("Subject")
                        TextField("Subject", text: $subject)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    
                    ZStack(alignment: .topLeading) {
                        MarkdownTextView(text: $bodyText, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                            .padding(.horizontal)
                        if bodyText.isEmpty {
                            Text("Message in Markdown…")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await send() }
                        } label: {
                            if isSending { ProgressView() } else { Text("Send") }
                        }
                        .disabled(isSending || subject.trimmingCharacters(in: .whitespaces).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationTitle("New Message")
                .navigationBarTitleDisplayMode(.inline)
                .alert("Couldn't send message", isPresented: .constant(error != nil)) {
                    Button("OK") { error = nil }
                } message: {
                    Text(error ?? "Unknown error")
                }
            }
        }
        
        private func send() async {
            guard !isSending else { return }
            isSending = true
            defer { isSending = false }
            do {
                try await redditAPI.composePrivateMessage(to: toUsername, subject: subject, text: bodyText)
                await MainActor.run { isPresented = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}
