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

struct CompactPostRowView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
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
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    var onRootReplyPosted: ((RedditComment) -> Void)? = nil
    
    init(post: RedditPost, namespace: Namespace.ID, selectedPost: Binding<RedditPost?>, onRootReplyPosted: ((RedditComment) -> Void)? = nil) {
        self.post = post
        self.namespace = namespace
        self._selectedPost = selectedPost
        self.onRootReplyPosted = onRootReplyPosted
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
        Card(style: .minimal) {
            HStack(alignment: .top, spacing: 10) {
                // Left: vertical voting + bottom ellipsis
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
                .frame(width: 28)

                // Middle: content
                VStack(alignment: .leading, spacing: 6) {
                    // Meta + inline score
                    HStack(spacing: 6) {
                        Text(subredditDisplayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("•").font(.caption2).foregroundStyle(.tertiary)

                        Text(post.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("•").font(.caption2).foregroundStyle(.tertiary)

                        Text(post.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("•").font(.caption2).foregroundStyle(.tertiary)

                        Text(scoreText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }

                    // Title navigates to post/comments page
                    Text(post.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .contentShape(Rectangle())

                    // Badges (tags keep their own coloring)
                    HStack(spacing: 4) {
                        if let linkFlairText = post.linkFlairText, !linkFlairText.isEmpty {
                            Text(linkFlairText)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(flairTextColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(flairBackgroundColor, in: Capsule())
                        }
                        if post.isNsfw {
                            Text("NSFW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.red, in: Capsule())
                        }
                        if post.isPinned || post.isStickied {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: tappable media + comments button underneath
                VStack(spacing: 6) {
                    compactThumbnail
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))

                    Pill(action: {
                        navigationPath.navigate(to: .postComments(post: currentPost))
                    }, size: .small) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.caption2)
                            Text("\(post.numComments)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { navigationPath.navigate(to: .postComments(post: currentPost)) }
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
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
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
        case .youtube:
            if let thumb = post.videoThumbnailURL ?? post.imageURL ?? validThumbnailURL {
                LazyImage(url: URL(string: thumb)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                    } else {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .matchedTransitionSource(id: "\(post.id)-youtube", in: namespace)
            } else {
                Image(systemName: "play.rectangle.on.rectangle")
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
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(post.galleryImages.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7), in: Capsule())
                                    .padding(4)
                            }
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
            if let thumbnail = validThumbnailURL {
                LazyImage(url: URL(string: thumbnail)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .overlay(alignment: .bottomLeading) {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                    Text(shortenedDomain)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(4)
                            }
                    } else {
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ZStack {
                    Image(systemName: "link")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption2)
                        Text(shortenedDomain)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(4)
                }
            }
        }
    }
    
    private var subredditDisplayName: String {
        return "r/\(post.subreddit)"
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
        return post.url != nil && (postType == .link || postType == .youtube)
    }
    
    // MARK: - Action Handlers
    
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
        
        // Show toast feedback
        showingCopiedToast = true
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Hide toast after delay
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

    private func submitRootReply(text: String) async throws {
        let parent = "t3_\(post.id)"
        let created = try await redditAPI.submitComment(parentFullname: parent, text: text)
        await MainActor.run {
            onRootReplyPosted?(created)
        }
    }
}
