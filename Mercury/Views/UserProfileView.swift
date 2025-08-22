import SwiftUI
import Nuke
import NukeUI
import Glur

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
    @State private var showProfileWeb = false
    @State private var showingCopiedToast = false
    @State private var animateHeader = false
    @Namespace private var sectionNamespace
    
    enum ProfileSection: String, CaseIterable, SectionPickerIconProvider {
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
                VStack(spacing: 0) {
                    header
                    
                    sectionPicker
                    
                    switch selectedSection {
                    case .posts:
                        postsList
                    case .comments:
                        commentsList
                    case .about:
                        aboutSection
                    }
                }
            }
            .refreshable { await refreshAll() }
        }
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
        .sheet(isPresented: $showCompose) {
            ComposeMessageSheet(toUsername: username, isPresented: $showCompose)
                .environment(\.redditAPI, redditAPI)
        }
        .sheet(isPresented: $showProfileWeb) {
            SafariView(url: profileURL)
        }
        .overlay(alignment: .top) {
            CopiedToast(isShowing: showingCopiedToast)
        }
        .animation(.easeInOut(duration: 0.2), value: showingCopiedToast)
    }
    
    // MARK: - Header
    
    private var header: some View {
        let headerHeight: CGFloat = 400
        let chipsPlaceholderHeight: CGFloat = 32
        
        return ZStack(alignment: .bottom) {
            // Background image with blur
            Group {
                if let url = profile?.profileIconURL ?? headerAvatarURL {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            gradientBackground
                        }
                    }
                    .priority(.high)
                } else {
                    gradientBackground
                }
            }
            .frame(height: headerHeight)
            .glur(radius: 8.0, offset: 0.4, interpolation: 0.6, direction: .down)
            .mask {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .white],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.08)
                )
                .blur(radius: 3)
            }
            

            
            // Content overlay
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Text("u/\(username)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                    
                    if let profile {
                        HStack(spacing: 12) {
                            labelChip(
                                system: "arrow.up.circle.fill",
                                text: "\(profile.totalKarma.formatted()) karma",
                                style: .prominent
                            )
                            if let cake = profile.created {
                                labelChip(
                                    system: "gift.fill",
                                    text: cakeDayText(cake),
                                    style: .secondary
                                )
                            }
                        }
                    } else {
                        Color.clear.frame(height: chipsPlaceholderHeight)
                    }
                }
                
                actionsGrid
            }
            .padding(.bottom, 24)
        }
        .frame(height: headerHeight)
    }
    
    private var gradientBackground: some View {
        LinearGradient(
            colors: [accentColor.opacity(0.8), accentColor.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func avatar(size: CGFloat = 72) -> some View {
        Group {
            if let url = profile?.profileIconURL ?? headerAvatarURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else if state.isLoading {
                        ZStack {
                            Circle().fill(Color.secondary.opacity(0.15))
                            ProgressView().progressViewStyle(.circular)
                        }
                    } else {
                        ZStack {
                            Circle().fill(Color.secondary)
                            Text(initials).font(.title).bold().foregroundStyle(.white)
                        }
                    }
                }
            } else if isLoading {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.15))
                    ProgressView().progressViewStyle(.circular)
                }
            } else {
                ZStack {
                    Circle().fill(Color.secondary)
                    Text(initials).font(.title).bold().foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    enum ChipStyle {
        case prominent
        case secondary
    }
    
    private func labelChip(system: String, text: String, style: ChipStyle = .prominent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(style == .prominent ? .white : .white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            style == .prominent ?
            Material.ultraThinMaterial :
                Material.thinMaterial,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
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
        
    private var sectionPicker: some View {
        SectionPicker(
            items: ProfileSection.allCases,
            selectedItem: $selectedSection,
            namespace: sectionNamespace,
            accentColor: .accentColor
        )
    }
        
        // MARK: - Quick Actions (Contacts-style)
    private var actionsGrid: some View {
            let items: [(String, String, Color, () -> Void)] = [
                ("message.fill", "Message", .blue, { showCompose = true }),
                ("square.and.arrow.up", "Share", .green, { shareProfile() }),
                ("safari", "Open", .orange, { showProfileWeb = true }),
                ("doc.on.doc", "Copy", .purple, { copyUsername() })
            ]
            return LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                spacing: 16
            ) {
                ForEach(0..<items.count, id: \.self) { i in
                    let item = items[i]
                    VStack(spacing: 8) {
                        Button(action: item.3) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.15))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                                Image(systemName: item.0)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 60, height: 60)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Text(item.1)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        
    private struct ScaleButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
                        }
                        if postsAfter != nil {
                            HStack {
                                Spacer(minLength: 0)
                                Pill(action: { Task { await loadMorePostsIfNeeded() } }) {
                                    HStack(spacing: 8) {
                                        if isLoadingMorePosts { ProgressView().controlSize(.small) }
                                        Image(systemName: "arrow.down.circle")
                                            .font(.headline)
                                        Text(isLoadingMorePosts ? "Loading more posts…" : "Load more posts")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .disabled(isLoadingMorePosts)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
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
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigationPath.navigate(to: .postComments(post: post))
                                    }
                            }
                        }
                        if commentsAfter != nil {
                            HStack {
                                Spacer(minLength: 0)
                                Pill(action: { Task { await loadMoreCommentsIfNeeded() } }) {
                                    HStack(spacing: 8) {
                                        if isLoadingMoreComments { ProgressView().controlSize(.small) }
                                        Image(systemName: "arrow.down.circle")
                                            .font(.headline)
                                        Text(isLoadingMoreComments ? "Loading more comments…" : "Load more comments")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .disabled(isLoadingMoreComments)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
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
            .padding(.top, 12)
        }
        
    private func sectionHeader(_ title: String) -> some View {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        
    private func infoRow(label: String, value: String) -> some View {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            .overlay(
                Divider()
                    .opacity(0.6)
                    .offset(y: 18),
                alignment: .bottom
            )
        }
        
        // MARK: - States
    private func loadingState(text: String) -> some View {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(accentColor)
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        }
        
    private func emptyState(title: String, message: String) -> some View {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.quaternary)
                
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
            .padding(.horizontal, 32)
        }
        
    private func errorState(message: String, retry: @escaping () -> Void) -> some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(.orange)
                
                VStack(spacing: 8) {
                    Text("Failed to load")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: retry) {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
            .padding(.horizontal, 32)
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
            guard await MainActor.run(body: { !isLoading }) else { return }
            await MainActor.run { isLoading = true; errorMessage = nil }
            defer { Task { await MainActor.run { isLoading = false } } }
            
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
            await MainActor.run {
                errorMessage = nil
                postsAfter = nil
                commentsAfter = nil
            }
            
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
                    self.errorMessage = nil // Clear any previous error on success
                }
                if await MainActor.run(body: { self.headerAvatarURL }) == nil && profile.profileIconURL == nil {
                    if let fetched = await redditAPI.fetchAvatarURL(username: username) {
                        await MainActor.run { self.headerAvatarURL = fetched }
                    }
                }
                await ensurePostsForComments(enrichedComments)
                await MainActor.run { commentsContextReady = true }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
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
        
    private var profileURL: URL { URL(string: "https://reddit.com/u/\(username)")! }
        
    private func copyUsername() {
            UIPasteboard.general.string = "u/\(username)"
            showingCopiedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showingCopiedToast = false }
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

