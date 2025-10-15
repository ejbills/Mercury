import SwiftUI
import UIKit
import Nuke
import NukeUI
import AVKit
import Defaults

struct PostRowView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    let showLargeToolbar: Bool
    let showFullText: Bool
    let onVideoHandoff: ((VideoHandoffState) -> Void)?
    var onHidePost: ((String) -> Void)? = nil
    var onHidePostsAbove: ((String) -> Void)? = nil
    let allowsNavigation: Bool
    @State private var showingSafari = false
    @State private var safariURL: URL? = nil
    @State private var isVoting = false
    @State private var shareItem: URL?
    @State private var shareItems: [URL]?
    @State private var isOfflinePlayerPresented = false
    @State private var offlinePlayer: AVPlayer? = nil
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var linkPreviewBlurred = false
    @State private var showShareSheet = false
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var savedState: Bool
    @State private var showingPostReply = false
    @State private var videoHandoffState: VideoHandoffState? = nil
    @Default(.postRightSwipeAction1) private var postRightAction1
    @Default(.postRightSwipeAction2) private var postRightAction2
    @Default(.postRightSwipeAction3) private var postRightAction3
    @Default(.postRightSwipeAction4) private var postRightAction4
    @Default(.readPostIds) private var readPostIds
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    var onRootReplyPosted: ((RedditComment) -> Void)? = nil
    
    @Default(.titleTextScale) private var titleScale
    @Default(.captionTextScale) private var captionScale
    // Appearance (Normal mode)
    @Default(.postNormalShowDomain) private var postShowDomain
    @Default(.postNormalShowFlair) private var postShowFlair
    @Default(.postNormalShowScore) private var postShowScore
    @Default(.postNormalShowCommentCount) private var postShowCommentCount
    @Default(.postNormalShowVoting) private var postShowVoting
    @Default(.postNormalVotingPosition) private var postVotingPosition
    @Default(.postNormalShowActions) private var postShowActions
    @Default(.postNormalUseCardStyle) private var postUseCardStyle
    @Default(.postHorizontalPadding) private var postHorizontalPadding

    init(post: RedditPost, namespace: Namespace.ID, selectedPost: Binding<RedditPost?>, showLargeToolbar: Bool = false, showFullText: Bool = false, onRootReplyPosted: ((RedditComment) -> Void)? = nil, onVideoHandoff: ((VideoHandoffState) -> Void)? = nil, onHidePost: ((String) -> Void)? = nil, onHidePostsAbove: ((String) -> Void)? = nil, allowsNavigation: Bool = true) {
        self.post = post
        self.namespace = namespace
        self._selectedPost = selectedPost
        self.showLargeToolbar = showLargeToolbar
        self.showFullText = showFullText
        self.onRootReplyPosted = onRootReplyPosted
        self.onVideoHandoff = onVideoHandoff
        self.onHidePost = onHidePost
        self.onHidePostsAbove = onHidePostsAbove
        self.allowsNavigation = allowsNavigation
        self.postType = post.postType
        let isRedditPostLink: Bool = {
            if let u = post.url?.lowercased() {
                return (u.contains("reddit.com/r/") && (u.contains("/comments/") || u.contains("/s/"))) || u.contains("redd.it/")
            }
            return false
        }()
        let hasContent = post.hasContent
        let hasThumbnail = (post.thumbnail != nil &&
                           post.thumbnail != "self" &&
                           post.thumbnail != "nsfw" &&
                           post.thumbnail != "spoiler" &&
                           post.thumbnail != "")
        let hasPreviewImages = (post.preview != nil && !(post.preview?.images.isEmpty ?? true))
        let isExternalLink = post.postType == .link && post.url != nil && 
                            post.domain != nil && 
                            !post.domain!.contains("reddit.com")
        
        self.shouldShowLinkPreview = (post.postType == .link && post.url != nil && (
            hasContent || hasThumbnail || hasPreviewImages || isExternalLink
        )) || isRedditPostLink
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
        self._savedState = State(initialValue: post.saved)
    }
    
    private let postType: PostType
    private let shouldShowLinkPreview: Bool
    
    private var hasMediaOrTextContent: Bool {
        switch postType {
        case .text:
            return post.hasContent
        case .image:
            return post.imageURL != nil
        case .gif:
            return post.gifURL != nil
        case .video:
            return post.videoURL != nil
        case .youtube:
            return post.url != nil
        case .gallery:
            return !post.galleryImages.isEmpty
        case .link:
            return shouldShowLinkPreview
        }
    }
    
    private var currentPost: RedditPost {
        var updatedPost = post
        updatedPost.currentVoteState = voteState
        updatedPost.displayScore = displayScore
        return updatedPost
    }
    
    private var resolvedCardStyle: CardStyle {
        CardStyle.default.withCornerRadius(CGFloat(Defaults[.postNormalCardCornerRadius]))
    }

    private var nonCardContentInsets: EdgeInsets {
        EdgeInsets(
            top: resolvedCardStyle.padding.top,
            leading: 0,
            bottom: resolvedCardStyle.padding.bottom,
            trailing: 0
        )
    }

    @ViewBuilder
    private var postCardBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                postHeader
                postTitle
            }

            if hasMediaOrTextContent {
                postMediaContent
                    .overlay {
                        if isDownloading && (post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery) {
                            downloadProgressOverlay
                        }
                    }
            }

            // Only show footer in feed, not in comments page
            if !showLargeToolbar {
                postFooter
            }
        }
    }
    
    var body: some View {
        Group {
            if postUseCardStyle {
                cardContainer
            } else {
                nonCardContainer
            }
        }
        .opacity(allowsNavigation && readPostIds.contains(post.id) ? 0.5 : 1.0)
        .padding(.horizontal, CGFloat(postHorizontalPadding))
        // Backwards-compat: if new right actions are unset, fall back to legacy right short/long
        .onAppear {
            if postRightAction1 == .none {
                let legacy1 = Defaults[.postRightShortSwipeAction]
                if legacy1 != .none { postRightAction1 = legacy1 }
            }
            if postRightAction2 == .none {
                let legacy2 = Defaults[.postRightLongSwipeAction]
                if legacy2 != .none { postRightAction2 = legacy2 }
            }
        }
        .contextMenu {
            if !post.locked && !post.archived {
                Button(action: { showingPostReply = true }) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
            }
            if post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery {
                Button(action: handleDownload) {
                    let label = switch post.postType {
                    case .video: "Download Video"
                    case .gif: "Download GIF"
                    case .image: "Download Image"
                    case .gallery: "Download Gallery"
                    default: "Download"
                    }
                    Label(label, systemImage: "arrow.down.circle")
                }
            }
            Button(action: handleShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(action: handleSave) {
                Label(savedState ? "Unsave" : "Save", systemImage: savedState ? "bookmark.fill" : "bookmark")
            }
            if let urlString = post.url, !urlString.isEmpty {
                Button(action: handleCopyLink) {
                    Label("Copy Link", systemImage: "link")
                }
                Button(action: handleOpenOriginal) {
                    Label("Open Original", systemImage: "safari")
                }
            }
        }
        .customSwipeGesture(
            right1: postRightAction1 != .none ? SwipeAction(
                type: postRightAction1,
                action: { await handleSwipeAction(postRightAction1) }
            ) : nil,
            right2: postRightAction2 != .none ? SwipeAction(
                type: postRightAction2,
                action: { await handleSwipeAction(postRightAction2) }
            ) : nil,
            right3: postRightAction3 != .none ? SwipeAction(
                type: postRightAction3,
                action: { await handleSwipeAction(postRightAction3) }
            ) : nil,
            right4: postRightAction4 != .none ? SwipeAction(
                type: postRightAction4,
                action: { await handleSwipeAction(postRightAction4) }
            ) : nil
        )
        .shadow(color: postUseCardStyle ? Color.black.opacity(0.05) : .clear,
                radius: postUseCardStyle ? 8 : 0,
                x: 0,
                y: postUseCardStyle ? 4 : 0)
        .sheet(isPresented: $showShareSheet) {
            if let urls = shareItems {
                MediaShareSheet(post: post, mediaURLs: urls)
            } else {
                MediaShareSheet(post: post, mediaURL: shareItem)
            }
        }
        .sheet(isPresented: $showingPostReply) {
            MarkdownComposerView(
                title: "Reply",
                accounts: redditAPI.availableAccountUsernames(),
                activeAccount: redditAPI.userInfo?.name ?? redditAPI.activeUsername,
                onCancel: { showingPostReply = false },
                onSubmit: { text, account in
                    try await submitRootReply(text: text, account: account)
                }
            )
        }
        .sheet(isPresented: $showingSafari) {
            if let urlString = post.url, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: Binding(get: { safariURL != nil }, set: { if !$0 { safariURL = nil } })) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }

        .sheet(isPresented: $isOfflinePlayerPresented) {
            if let player = offlinePlayer {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .ignoresSafeArea()
            }
        }
    }

    private func navigateToComments() {
        navigationPath.navigate(to: .postComments(post: currentPost))
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35 seconds
            _ = await MainActor.run {
                readPostIds.insert(post.id)
            }
        }
    }

    @ViewBuilder
    private var cardContainer: some View {
        let card = Card(style: resolvedCardStyle) {
            postCardBody
        }
        if allowsNavigation {
            card
                .onTap { navigateToComments() }
        } else {
            card
        }
    }

    @ViewBuilder
    private var nonCardContainer: some View {
        let content = VStack(spacing: 0) {
            Divider()
            postCardBody
                .padding(nonCardContentInsets)
            Divider()
        }
        .contentShape(Rectangle())

        if allowsNavigation {
            content
                .onTapGesture { navigateToComments() }
        } else {
            content
        }
    }
    
    private var postHeader: some View {
        PostHeader(post: post, colorScheme: .light)
    }
    
    private var postTitle: some View {
        InlineTitleLabel(
            title: post.title,
            flairText: postShowFlair ? post.linkFlairText : nil,
            isNSFW: post.isNsfw,
            isSpoiler: post.isSpoiler,
            showDomain: postShowDomain && (postType == .link && !(post.domain?.isEmpty ?? true)),
            domainText: shortenedDomain,
            flairBackground: UIColor(flairBackgroundColor),
            flairTextColor: UIColor(flairTextColor),
            textColor: UIColor.label,
            titlePointSize: CGFloat(16) * CGFloat(titleScale),
            titleWeight: .medium,
            pillPointSize: CGFloat(12) * CGFloat(captionScale),
            pillWeight: .medium,
            isPinned: post.isPinned || post.isStickied,
            isLocked: post.locked,
            isArchived: post.archived,
            gildedCount: post.gilded
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var shortenedDomain: String {
        guard let domain = post.domain else { return "" }
        if domain.hasPrefix("www.") {
            return String(domain.dropFirst(4))
        }
        return domain
    }
    
    @ViewBuilder
    private var postMediaContent: some View {
        switch postType {
        case .text:
            if post.hasContent {
                textPostContent
            }
        case .image:
            VStack(alignment: .leading, spacing: 12) {
                if let imageURL = post.imageURL {
                    SimpleImageView(
                        url: imageURL,
                        mediaId: "\(post.id)-image",
                        title: post.title,
                        namespace: namespace,
                        apiDimensions: post.imageDimensions,
                        post: post,
                        selectedPost: $selectedPost
                    )
                }
                
                if showFullText && post.hasContent, let content = post.selftext, !content.isEmpty {
                    MarkdownRenderer(content: content, compactMode: !showFullText, showEmbeddedContent: showFullText)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                SimpleGifView(
                    url: url,
                    mediaId: "\(post.id)-gif",
                    title: post.title,
                    namespace: namespace,
                    post: post,
                    selectedPost: $selectedPost
                )
            }
        case .video:
            if post.videoURL != nil {
                SimpleVideoView(
                    videoURL: post.videoURL!,
                    thumbnailURL: post.videoThumbnailURL ?? post.imageURL,
                    mediaId: "\(post.id)-video",
                    title: post.title,
                    namespace: namespace,
                    apiDimensions: post.videoThumbnailDimensions,
                    post: post,
                    onRequestDetail: { handoffState in
                        videoHandoffState = handoffState
                        onVideoHandoff?(handoffState)
                        selectedPost = post
                    },
                    resumeFromState: videoHandoffState
                )
            }
        case .youtube:
            if let youtubeURL = post.url {
                CompactArticleCard(
                    url: youtubeURL,
                    fallbackThumbnail: validThumbnailURL,
                    fallbackDomain: post.domain,
                    fallbackTitle: post.title
                ) {
                    let normalized = URLNormalizer.normalizeRedditURL(youtubeURL)
                    if let url = URL(string: normalized) { safariURL = url }
                }
            }
        case .gallery:
            VStack(alignment: .leading, spacing: 12) {
                SimpleGalleryView(
                    post: post,
                    mediaId: "\(post.id)-gallery",
                    namespace: namespace,
                    selectedPost: $selectedPost
                )
                if showFullText && post.hasContent, let content = post.selftext, !content.isEmpty {
                    MarkdownRenderer(content: content, compactMode: !showFullText, showEmbeddedContent: showFullText)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        case .link:
            if shouldShowLinkPreview {
                linkPostContent
            }
        }
    }
    
    @ViewBuilder
    private var textPostContent: some View {
        if let content = post.selftext, !content.isEmpty {
            MarkdownRenderer(content: content, compactMode: !showFullText, showEmbeddedContent: showFullText)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    private var linkPostContent: some View {
        if let urlString = post.url {
            if isRedditPostURL(urlString) {
                CompactRedditPostCard(url: urlString) { linkedPost in
                    if let linkedPost = linkedPost {
                        navigationPath.navigate(to: .postComments(post: linkedPost))
                    } else {
                        // Normalize to https Reddit URL and try fetch again; else open safely in Safari
                        let normalized = URLNormalizer.normalizeRedditURL(urlString)
                        Task {
                            if let fetched = await RedditPostFetchService.shared.fetchPost(from: normalized) {
                                await MainActor.run { navigationPath.navigate(to: .postComments(post: fetched)) }
                            } else if let url = URL(string: normalized) {
                                await MainActor.run { safariURL = url }
                            }
                        }
                    }
                }
                .sensitiveContentBlurred(post: post, contentType: .link, isBlurred: $linkPreviewBlurred)
            } else {
                CompactArticleCard(
                    url: urlString,
                    fallbackThumbnail: validThumbnailURL,
                    fallbackDomain: post.domain,
                    fallbackTitle: post.title
                ) {
                    let normalized = URLNormalizer.normalizeRedditURL(urlString)
                    if let url = URL(string: normalized) { safariURL = url }
                }
                .sensitiveContentBlurred(post: post, contentType: .link, isBlurred: $linkPreviewBlurred)
            }
        }
    }

    // Normalization centralized in URLNormalizer

    private func isRedditPostURL(_ url: String) -> Bool {
        let u = url.lowercased()
        return (u.contains("reddit.com/r/") && (u.contains("/comments/") || u.contains("/s/"))) || u.contains("redd.it/")
    }
    
    private var validThumbnailURL: String? {
        guard let thumbnail = post.thumbnail,
              thumbnail != "self",
              thumbnail != "default", 
              thumbnail != "nsfw",
              thumbnail != "spoiler",
              !thumbnail.isEmpty else {
            return nil
        }
        return thumbnail
    }
    
    private var postFooter: some View {
        HStack(alignment: .center, spacing: 8) {
            // Left side - voting buttons if positioned left
            if postShowVoting && postVotingPosition == .left {
                VotingCluster(
                    post: currentPost,
                    voteState: $voteState,
                    displayScore: $displayScore,
                    isVoting: $isVoting,
                    onVote: handleVote,
                    colorScheme: .light,
                    size: .compact
                )
            }

            // If voting is on left, push score/comment pills to the right
            if postVotingPosition == .left {
                Spacer()
            }

            // Upvote score pill (tappable toggle)
            if postShowScore {
                Pill(action: {
                    handleVote(voteState == .upvoted ? .neutral : .upvoted)
                }, size: .regular) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.callout)
                        Text(scoreText)
                            .appFont(.caption, weight: .medium)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(scoreColor)
                }
            }

            // Comment count pill
            if postShowCommentCount {
                Pill {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.callout)
                        Text(post.commentsText)
                            .appFont(.caption, weight: .medium)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // If voting is on right, push them to the right side
            if postVotingPosition == .right {
                Spacer()
            }

            // Right side - voting buttons if positioned right
            if postShowVoting && postVotingPosition == .right {
                VotingCluster(
                    post: currentPost,
                    voteState: $voteState,
                    displayScore: $displayScore,
                    isVoting: $isVoting,
                    onVote: handleVote,
                    colorScheme: .light,
                    size: .compact
                )
            }
        }
    }

    private var scoreText: String {
        let score = max(0, displayScore)
        if score >= 1000 {
            let kScore = Double(score) / 1000.0
            return String(format: "%.1fk", kScore)
        } else {
            return String(score)
        }
    }
    
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted: return .orange
        case .downvoted: return .blue
        case .neutral: return .secondary
        }
    }
    
    
    private var flairBackgroundColor: Color {
        if let colorHex = post.linkFlairBackgroundColor, !colorHex.isEmpty {
            return Color(hex: colorHex) ?? Color.accentColor.opacity(0.2)
        }
        return Color.accentColor.opacity(0.2)
    }
    
    private var flairTextColor: Color {
        if let colorHex = post.linkFlairTextColor, colorHex == "dark" {
            return .primary
        } else if let colorHex = post.linkFlairTextColor, colorHex == "light" {
            return .white
        }
        return .primary
    }
    
    // MARK: - Action Handlers
    
    private func handleVote(_ newVoteState: RedditPost.VoteState) {
        guard !isVoting else { return }
        
        let originalState = voteState
        let originalScore = displayScore
        
        withAnimation(.bouncy(duration: 0.4)) {
            let scoreDelta = calculateScoreDelta(from: voteState, to: newVoteState)
            voteState = newVoteState
            displayScore = max(0, displayScore + scoreDelta)
        }
        
        isVoting = true
        
        Task {
            do {
                let voteDirection: VoteDirection = switch newVoteState {
                case .upvoted: .upvote
                case .downvoted: .downvote
                case .neutral: .neutral
                }
                
                try await redditAPI.voteOnPost(postId: post.id, voteDirection: voteDirection)
                
                await MainActor.run {
                    isVoting = false
                }
            } catch {
                await MainActor.run {
                    withAnimation(.bouncy(duration: 0.4)) {
                        voteState = originalState
                        displayScore = originalScore
                    }
                    isVoting = false
                }
            }
        }
    }
    
    private func calculateScoreDelta(from oldState: RedditPost.VoteState, to newState: RedditPost.VoteState) -> Int {
        switch (oldState, newState) {
        case (.neutral, .upvoted): return 1
        case (.neutral, .downvoted): return -1
        case (.upvoted, .neutral): return -1
        case (.upvoted, .downvoted): return -2
        case (.downvoted, .neutral): return 1
        case (.downvoted, .upvoted): return 2
        default: return 0
        }
    }
    
    private func handleShare() {
        shareItems = nil // Ensure we use metadata-based share when no downloads are present
        shareItem = nil  // No media file to share
        showShareSheet = true
    }
    
    private func handleSave() {
        Task {
            let originalState = savedState
            await MainActor.run {
                savedState.toggle()
            }
            
            do {
                if originalState {
                    try await redditAPI.unsavePost(postId: post.id)
                } else {
                    try await redditAPI.savePost(postId: post.id)
                }
            } catch {
                print("Save/Unsave error: \(error)")
                await MainActor.run {
                    savedState = originalState // Revert on error
                }
            }
        }
    }
    
    private func handleCopyLink() {
        UIPasteboard.general.string = post.permalinkURL

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleOpenOriginal() {
        showingSafari = true
    }
    
    private func handleDownload() {
        guard post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery else { return }
        guard !isDownloading else { return }
        isDownloading = true
        Task {
            defer { isDownloading = false }
            do {
                let service = MediaDownloadService()
                if post.postType == .gallery {
                    let urls = try await service.downloadAllGalleryImages(post: post, options: .init(
                        preferredFilename: post.id,
                        onProgress: { progress in
                            Task { @MainActor in
                                downloadProgress = progress
                            }
                        }
                    ))
                    await MainActor.run {
                        shareItems = urls
                        shareItem = nil
                        showShareSheet = true
                    }
                } else {
                    let fileURL = try await service.download(post: post, options: .init(
                        preferredFilename: post.id,
                        onProgress: { progress in
                            Task { @MainActor in
                                downloadProgress = progress
                            }
                        }
                    ))
                    await MainActor.run {
                        shareItem = fileURL
                        shareItems = nil
                        showShareSheet = true
                    }
                }
            } catch {
                // On failure, do not present share sheet with metadata
            }
        }
    }

    private func submitRootReply(text: String, account: String) async throws {
        let parent = post.fullname
        let created = try await redditAPI.performUsingAccount(username: account) {
            try await redditAPI.submitComment(parentFullname: parent, text: text)
        }
        await MainActor.run {
            onRootReplyPosted?(created)
        }
    }
    
    private func handleSwipeAction(_ actionType: SwipeActionType) async {
        await MainActor.run {
            switch actionType {
            case .upvote:
                handleVote(.upvoted)
            case .downvote:
                handleVote(.downvoted)
            case .save:
                handleSave()
            case .share:
                handleShare()
            case .reply:
                showingPostReply = true
            case .profile:
                navigationPath.navigate(to: .userProfile(username: post.author))
            case .subreddit:
                navigationPath.navigate(to: .subredditFeed(subreddit: post.subreddit))
            case .hide:
                onHidePost?(post.id)
            case .hideAbove:
                onHidePostsAbove?(post.id)
            case .copyLink:
                handleCopyLink()
            case .collapse, .collapseToTop, .parentComment, .none:
                // Comment-specific actions not applicable to posts
                break
            }
        }
    }
    
    @ViewBuilder
    private var downloadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                VStack(spacing: 4) {
                    let downloadText = switch post.postType {
                    case .video: "Downloading Video"
                    case .gif: "Downloading GIF"
                    case .image: "Downloading Image"
                    case .gallery: "Downloading Gallery"
                    default: "Downloading"
                    }

                    Text(downloadText)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloadProgress)
    }
}

struct PostRowShareableItem: Identifiable {
    let id = UUID()
    let url: URL
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
