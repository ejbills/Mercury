import SwiftUI
import Nuke
import NukeUI
import AVKit

struct PostRowView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    let showLargeToolbar: Bool
    let showFullText: Bool
    let onVideoHandoff: ((VideoHandoffState) -> Void)?
    @State private var showingSafari = false
    @State private var isVoting = false
    @State private var showingCopiedToast = false
    @State private var shareItem: URL?
    @State private var isOfflinePlayerPresented = false
    @State private var offlinePlayer: AVPlayer? = nil
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showShareSheet = false
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var showingPostReply = false
    @State private var videoHandoffState: VideoHandoffState? = nil
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    var onRootReplyPosted: ((RedditComment) -> Void)? = nil
    
    init(post: RedditPost, namespace: Namespace.ID, selectedPost: Binding<RedditPost?>, showLargeToolbar: Bool = false, showFullText: Bool = false, onRootReplyPosted: ((RedditComment) -> Void)? = nil, onVideoHandoff: ((VideoHandoffState) -> Void)? = nil) {
        self.post = post
        self.namespace = namespace
        self._selectedPost = selectedPost
        self.showLargeToolbar = showLargeToolbar
        self.showFullText = showFullText
        self.onRootReplyPosted = onRootReplyPosted
        self.onVideoHandoff = onVideoHandoff
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
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    postHeader
                    postTitle
                }
                
                if hasMediaOrTextContent {
                    postMediaContent
                        .overlay {
                            if isDownloading && (post.postType == .video || post.postType == .gif || post.postType == .image) {
                                downloadProgressOverlay
                            }
                        }
                }
                
                postFooter
                
                if showLargeToolbar {
                    HStack(spacing: 20) {
                        VotingCluster(
                            post: currentPost,
                            voteState: $voteState,
                            displayScore: $displayScore,
                            isVoting: $isVoting,
                            onVote: handleVote,
                            colorScheme: .light,
                            size: .large
                        )
                        
                        Spacer()
                        
                        PostActionToolbar(
                            post: currentPost,
                            voteState: $voteState,
                            displayScore: $displayScore,
                            isVoting: $isVoting,
                            onVote: handleVote,
                            onReply: { showingPostReply = true },
                            onShare: handleShare,
                            onSave: handleSave,
                            onCopyLink: handleCopyLink,
                            onOpenOriginal: handleOpenOriginal,
                            onCommentsAction: nil,
                            onDownload: handleDownload,
                            colorScheme: .light,
                            size: .large
                        )
                    }
                } else {
                    PostActionToolbar(
                        post: currentPost,
                        voteState: $voteState,
                        displayScore: $displayScore,
                        isVoting: $isVoting,
                        onVote: handleVote,
                        onReply: { showingPostReply = true },
                        onShare: handleShare,
                        onSave: handleSave,
                        onCopyLink: handleCopyLink,
                        onOpenOriginal: handleOpenOriginal,
                        onCommentsAction: {
                            navigationPath.navigate(to: .postComments(post: currentPost))
                        },
                        onDownload: handleDownload,
                        colorScheme: .light,
                        size: .compact
                    )
                }
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            width - 32 // 16pt margin on each side
        }
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showShareSheet) {
            MediaShareSheet(post: post, mediaURL: shareItem)
        }
        .sheet(isPresented: $showingPostReply) {
            MarkdownComposerView(
                title: "Reply",
                onCancel: { showingPostReply = false },
                onSubmit: { text in
                    try await submitRootReply(text: text)
                }
            )
        }
        .sheet(isPresented: $showingSafari) {
            if let urlString = post.url, let url = URL(string: urlString) {
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
    
    private var postHeader: some View {
        PostHeader(post: post, colorScheme: .light)
    }
    
    private var postTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            
            
            HStack(spacing: 6) {
                if let linkFlairText = post.linkFlairText, !linkFlairText.isEmpty {
                    Pill(size: .small) {
                        Text(linkFlairText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(flairTextColor)
                    }
                    .background(flairBackgroundColor, in: Capsule())
                }
                
                if post.isPinned || post.isStickied {
                    Pill(size: .small) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                if post.isNsfw {
                    Pill(size: .small) {
                        Text("NSFW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .background(.red, in: Capsule())
                }
                
                if post.isSpoiler {
                    Pill(size: .small) {
                        Text("SPOILER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .background(.orange, in: Capsule())
                }
                
                if post.postType == .link && !(post.domain?.isEmpty ?? true) {
                    Pill(size: .small) {
                        Text(shortenedDomain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if post.gilded > 0 {
                    Pill(size: .small) {
                        HStack(spacing: 3) {
                            Image(systemName: "seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            
                            if post.gilded > 1 {
                                Text("\(post.gilded)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                if post.locked {
                    Pill(size: .small) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                if post.archived {
                    Pill(size: .small) {
                        Image(systemName: "archivebox.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
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
                YouTubeEmbedView(url: youtubeURL)
            }
        case .gallery:
            SimpleGalleryView(
                post: post,
                mediaId: "\(post.id)-gallery",
                namespace: namespace,
                selectedPost: $selectedPost
            )
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
                RedditPostCard(url: urlString) { linkedPost in
                    if let linkedPost = linkedPost {
                        navigationPath.navigate(to: .postComments(post: linkedPost))
                    } else {
                        showingSafari = true
                    }
                }
            } else {
                RichArticleCard(
                    url: urlString,
                    fallbackThumbnail: validThumbnailURL,
                    fallbackDomain: post.domain,
                    fallbackTitle: post.title
                ) {
                    showingSafari = true
                }
            }
        }
    }

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
        HStack(spacing: 8) {
            InlineToast(isShowing: showingCopiedToast)
            Spacer()
        }
    }
    
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted: return .orange
        case .downvoted: return .blue
        case .neutral: return .primary
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
        shareItem = nil  // No media file to share
        showShareSheet = true
    }
    
    private func handleSave() {
        Task {
            do {
                if post.saved {
                    try await redditAPI.unsavePost(postId: post.id)
                    await MainActor.run {
                    }
                } else {
                    try await redditAPI.savePost(postId: post.id)
                    await MainActor.run {
                    }
                }
            } catch {
                print("Save/Unsave error: \(error)")
                
            }
        }
    }
    
    private func handleCopyLink() {
        UIPasteboard.general.string = post.permalinkURL
        
        showingCopiedToast = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                showingCopiedToast = false
            }
        }
    }
    
    private func handleOpenOriginal() {
        showingSafari = true
    }
    
    private func handleDownload() {
        guard post.postType == .video || post.postType == .gif || post.postType == .image else { return }
        guard !isDownloading else { return }
        isDownloading = true
        Task {
            defer { isDownloading = false }
            do {
                let service = MediaDownloadService()
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
                    showShareSheet = true
                }
            } catch {
                
                await MainActor.run {
                    shareItem = URL(string: post.permalinkURL)
                    showShareSheet = true
                }
            }
        }
    }

    private func submitRootReply(text: String) async throws {
        let parent = "t3_\(post.id)"
        let created = try await redditAPI.submitComment(parentFullname: parent, text: text)
        await MainActor.run {
            onRootReplyPosted?(created)
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
                    case .youtube: "Opening YouTube"
                    case .gif: "Downloading GIF"
                    case .image: "Downloading Image"
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
