//
//  CompactPostRowView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI
import Nuke
import NukeUI
import AVKit
import UIKit
import Defaults

struct CompactPostRowView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    @State private var showingSafari = false
    @State private var isVoting = false
    @State private var shareItem: URL?
    @State private var isOfflinePlayerPresented = false
    @State private var offlinePlayer: AVPlayer? = nil
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var compactThumbnailBlurred = false
    @State private var showShareSheet = false
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var showingPostReply = false
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    var onRootReplyPosted: ((RedditComment) -> Void)? = nil
    // no-op
    let allowsNavigation: Bool
    @Default(.titleTextScale) private var titleScale
    @Default(.captionTextScale) private var captionScale
    // Appearance (Compact)
    @Default(.postCompactThumbnailSize) private var postThumbSize
    @Default(.postCompactShowThumbnail) private var postShowThumbnail
    @Default(.postCompactHideTextThumbnails) private var postHideTextThumbs
    @Default(.postCompactShowSubreddit) private var postShowSubreddit
    @Default(.postCompactShowSubredditIcon) private var postShowSubredditIcon
    @Default(.postCompactShowAuthor) private var postShowAuthor
    @Default(.postCompactShowAvatar) private var postShowAvatar
    @Default(.postCompactShowTime) private var postShowTime
    @Default(.postCompactShowDomain) private var postShowDomain
    @Default(.postCompactShowFlair) private var postShowFlair
    @Default(.postCompactShowScore) private var postShowScore
    @Default(.postCompactShowCommentCount) private var postShowCommentCount
    @Default(.postCompactShowVoting) private var postShowVoting
    @Default(.postCompactThumbnailPosition) private var postThumbPosition
    @Default(.postCompactShowActions) private var postShowActions
    @Default(.postCompactUseCardStyle) private var postUseCardStyle
    @Default(.postHorizontalPadding) private var postHorizontalPadding
    // Right-side swipe actions (compact)
    @Default(.postRightSwipeAction1) private var postRightAction1
    @Default(.postRightSwipeAction2) private var postRightAction2
    @Default(.postRightSwipeAction3) private var postRightAction3
    @Default(.postRightSwipeAction4) private var postRightAction4
    
    init(post: RedditPost, namespace: Namespace.ID, selectedPost: Binding<RedditPost?>, onRootReplyPosted: ((RedditComment) -> Void)? = nil, allowsNavigation: Bool = true) {
        self.post = post
        self.namespace = namespace
        self._selectedPost = selectedPost
        self.onRootReplyPosted = onRootReplyPosted
        self.allowsNavigation = allowsNavigation
        self.postType = post.postType
        // Detect reddit post links (crossposts/embedded posts) regardless of thumbnail
        let isRedditPostLink: Bool = {
            if let u = post.url?.lowercased() {
                return (u.contains("reddit.com/r/") && (u.contains("/comments/") || u.contains("/s/"))) || u.contains("redd.it/")
            }
            return false
        }()
        self.shouldShowLinkPreview = (post.postType == .link && post.url != nil && (
            post.hasContent || (post.thumbnail != nil &&
                                post.thumbnail != "self" &&
                                post.thumbnail != "default" &&
                                post.thumbnail != "nsfw" &&
                                post.thumbnail != "spoiler" &&
                                post.thumbnail != "")
        )) || isRedditPostLink
        // Initialize state properties
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
    }
    
    // Optimization: compute expensive properties once
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

    private var compactSensitiveContentType: SensitiveContentOverlay.ContentType {
        switch postType {
        case .text:
            return .text
        case .image:
            return .image
        case .gif:
            return .gif
        case .video:
            return .video
        case .gallery:
            return .gallery
        case .link:
            return .link
        }
    }

    private var resolvedCardStyle: CardStyle {
        CardStyle.minimal.withCornerRadius(CGFloat(Defaults[.postCompactCardCornerRadius]))
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
    private var compactRowBody: some View {
        HStack(alignment: .top, spacing: 10) {
            if postThumbPosition == .left {
                if shouldShowCompactThumbnail { thumbnailColumn }
                contentColumn
                if postShowVoting { votingColumn }
            } else {
                if postShowVoting { votingColumn }
                contentColumn
                if shouldShowCompactThumbnail { thumbnailColumn }
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
        .padding(.horizontal, CGFloat(postHorizontalPadding))
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
        .sheet(isPresented: $showShareSheet) {
            MediaShareSheet(post: post, mediaURL: shareItem)
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
    }

    @ViewBuilder
    private var cardContainer: some View {
        let card = Card(style: resolvedCardStyle) {
            compactRowBody
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
            compactRowBody
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
    
    @ViewBuilder
    private var compactThumbnail: some View {
        switch postType {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        case .image:
            if let imageURL = post.imageURL {
                LazyImage(url: URL(string: imageURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .matchedTransitionSource(id: "\(post.id)-image", in: namespace)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "play.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .matchedTransitionSource(id: "\(post.id)-gif", in: namespace)
            } else {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        case .video:
            if let thumbnailURL = post.videoThumbnailURL ?? post.imageURL {
                LazyImage(url: URL(string: thumbnailURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "play.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .matchedTransitionSource(id: "\(post.id)-video", in: namespace)
            } else {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        case .gallery:
            if let firstImage = post.galleryImages.first {
                LazyImage(url: URL(string: firstImage.url)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo.stack")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .matchedTransitionSource(id: "\(post.id)-gallery", in: namespace)
            } else {
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        case .link:
            if let previewURL = post.imageURL ?? validThumbnailURL, let url = URL(string: previewURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var subredditDisplayName: String {
        return "r/\(post.subreddit)"
    }

    // MARK: - Column Builders
    private var votingColumn: some View {
        VStack(spacing: 4) {
            VoteButton(
                direction: .up,
                isActive: voteState == .upvoted,
                size: .small,
                colorScheme: .light,
                disabled: isVoting
            ) { handleVote(.upvoted) }

            VoteButton(
                direction: .down,
                isActive: voteState == .downvoted,
                size: .small,
                colorScheme: .light,
                disabled: isVoting
            ) { handleVote(.downvoted) }

            Spacer(minLength: 0)
        }
        .frame(width: 28)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Meta + inline score
            HStack(spacing: 8) {
                if postShowSubreddit {
                    // Subreddit + icon
                    HStack(spacing: 4) {
                        if postShowSubredditIcon {
                            SubredditIcon(iconURL: post.subredditIconURL, displayName: post.subreddit, size: 14)
                        }
                        Text(subredditDisplayName)
                            .appFont(.caption, weight: .medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if postShowAuthor {
                    // Author + avatar
                    HStack(spacing: 4) {
                        if postShowAvatar { UserAvatar(username: post.author, size: 14, iconURL: post.authorIconURL) }
                        Text(post.author)
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if postShowTime {
                    Text(post.timeAgo)
                        .appFont(.small)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if postShowScore {
                    Pill(action: {
                        handleVote(voteState == .upvoted ? .neutral : .upvoted)
                    }, size: .small) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                            Text(scoreText)
                                .appFont(.small, weight: .semibold)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(scoreColor)
                    }
                }

                Spacer(minLength: 0)

                if postShowCommentCount {
                    commentBadge
                }

                if postShowActions {
                    overflowMenu
                }
            }
            .lineLimit(1)

            // Inline title + pills via UIKit-backed label for robust wrapping
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
                titlePointSize: CGFloat(14) * CGFloat(titleScale),
                titleWeight: .medium,
                pillPointSize: CGFloat(12) * CGFloat(captionScale),
                pillWeight: .medium
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var commentBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "bubble.left")
                .font(.caption2)
            Text("\(post.numComments)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
    }

    private var overflowMenu: some View {
        Menu {
            Button(action: { handleSave() }) {
                Label(post.saved ? "Unsave" : "Save",
                      systemImage: post.saved ? "bookmark.fill" : "bookmark")
            }
            Button(action: { handleShare() }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(action: { handleCopyLink() }) {
                Label("Copy Link", systemImage: "link")
            }
            if shouldShowOpenOriginal {
                Button(action: { handleOpenOriginal() }) {
                    Label("Open Original", systemImage: "arrow.up.right.square")
                }
            }
        } label: {
            GlassMenuLabel(systemImage: "ellipsis", foreground: .secondary, font: .caption)
        }
    }

    private var thumbnailColumn: some View {
        VStack(spacing: 4) {
            if shouldShowCompactThumbnail {
                compactThumbnail
                    .frame(width: postThumbSize.dimension, height: postThumbSize.dimension)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .center) { mediaBadge }
                    .sensitiveContentBlurred(post: post, contentType: compactSensitiveContentType, isBlurred: $compactThumbnailBlurred, cornerRadius: 8)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .highPriorityGesture(TapGesture().onEnded { handleThumbnailTap() })
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
        case .neutral: return .primary
        }
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

    private var shouldShowCompactThumbnail: Bool {
        guard postShowThumbnail else { return false }
        if postHideTextThumbs && postType == .text { return false }
        return true
    }

    private var shortenedDomain: String {
        guard let domain = post.domain else { return "" }
        if domain.hasPrefix("www.") { return String(domain.dropFirst(4)) }
        return domain
    }

    // Flair colors consistent with full post view
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
    
    private var shouldShowOpenOriginal: Bool {
        return post.url != nil && postType == .link
    }
    
    // Subtle corner media badge for compact thumbnails
    @ViewBuilder
    private var mediaBadge: some View {
        switch postType {
        case .video:
            badgeBackground {
                Image(systemName: "play.fill").font(.caption2).fontWeight(.bold)
            }
        case .gif:
            badgeBackground {
                Text("GIF").font(.caption2).fontWeight(.heavy)
            }
        case .gallery:
            badgeBackground {
                HStack(spacing: 3) {
                    Image(systemName: "photo.on.rectangle").font(.caption2)
                    Text("\(max(1, post.galleryImages.count))").font(.caption2).fontWeight(.bold)
                }
            }
        case .link:
            badgeBackground {
                Image(systemName: "link").font(.caption2)
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeBackground<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(4)
    }
    
    // MARK: - Action Handlers
    
    private func handleThumbnailTap() {
        switch postType {
        case .image, .gif, .video, .gallery:
            selectedPost = post
        case .link:
            showingSafari = true
        case .text:
            if allowsNavigation {
                navigationPath.navigate(to: .postComments(post: currentPost))
            }
        }
    }
    
    private func handleVote(_ newVoteState: RedditPost.VoteState) {
        guard !isVoting else { return }
        
        let originalState = voteState
        let originalScore = displayScore
        
        // Apply optimistic update with iOS 18+ spring animation
        withAnimation(.bouncy(duration: 0.4)) {
            // Calculate score change
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
                // Revert optimistic update on error with bounce animation
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
        // Simple share always shares the post URL, not the media
        shareItem = nil  // No media file to share
        showShareSheet = true
    }
    
    private func handleSave() {
        Task {
            do {
                if post.saved {
                    try await redditAPI.unsavePost(postId: post.id)
                    await MainActor.run {
                        // Note: We can't directly mutate post.saved as it's not part of our mutable state
                        // This would typically be handled by refreshing the post data
                    }
                } else {
                    try await redditAPI.savePost(postId: post.id)
                    await MainActor.run {
                        // Note: We can't directly mutate post.saved as it's not part of our mutable state
                        // This would typically be handled by refreshing the post data
                    }
                }
            } catch {
                // Handle error silently for now
                print("Save/Unsave error: \(error)")
                
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

    private func submitRootReply(text: String, account: String) async throws {
        let parent = "t3_\(post.id)"
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
            case .copyLink:
                handleCopyLink()
            case .hide, .hideAbove, .collapse, .collapseToTop, .parentComment, .markRead, .markUnread, .deleteMessage, .none:
                break
            }
        }
    }
}

// Moved InlineTitleLabel to a shared component for reuse
