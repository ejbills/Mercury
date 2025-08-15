//
//  PostRowView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI

struct PostRowView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    @State private var showingSafari = false
    @State private var isVoting = false
    @State private var showingCopiedToast = false
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(post: RedditPost, namespace: Namespace.ID, selectedPost: Binding<RedditPost?>) {
        self.post = post
        self.namespace = namespace
        self._selectedPost = selectedPost
        self.postType = post.postType
        self.shouldShowLinkPreview = post.postType == .link && post.url != nil && (
            post.hasContent || (post.thumbnail != nil && 
                               post.thumbnail != "self" && 
                               post.thumbnail != "default" && 
                               post.thumbnail != "nsfw" && 
                               post.thumbnail != "spoiler" &&
                               post.thumbnail != "")
        )
        // Initialize state properties
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
    }
    
    // Optimization: compute expensive properties once
    private let postType: PostType
    private let shouldShowLinkPreview: Bool
    
    private var currentPost: RedditPost {
        var updatedPost = post
        updatedPost.currentVoteState = voteState
        updatedPost.displayScore = displayScore
        return updatedPost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with better spacing
            VStack(alignment: .leading, spacing: 8) {
                postHeader
                postTitle
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            postMediaContent
                .padding(.horizontal, 16)
            
            postFooter
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Bottom action toolbar
            bottomActionToolbar
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .containerRelativeFrame(.horizontal) { width, _ in
            width - 32 // 16pt margin on each side
        }
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingSafari) {
            if let urlString = post.url, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
    }
    
    private var postHeader: some View {
        HStack(alignment: .top) {
            Button(action: {
                navigationPath.navigate(to: .subredditFeed(subreddit: post.subreddit))
            }) {
                Text(post.displaySubreddit)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Right side: User and time in VStack
            VStack(alignment: .trailing, spacing: 2) {
                Button(action: {
                    navigationPath.navigate(to: .userProfile(username: post.author))
                }) {
                    Text("u/\(post.author)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Text(post.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var postTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title with better typography - ALWAYS show full title
            Text(post.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil) // Remove line limit to always show full title
                .fixedSize(horizontal: false, vertical: true)
            
            // Tags under title for better hierarchy
            HStack(spacing: 6) {
                // Post flair first if available
                if let linkFlairText = post.linkFlairText, !linkFlairText.isEmpty {
                    Text(linkFlairText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(flairTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(flairBackgroundColor, in: RoundedRectangle(cornerRadius: 4))
                }
                
                if post.isPinned || post.isStickied {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                
                if post.isNsfw {
                    Text("NSFW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.red, in: RoundedRectangle(cornerRadius: 3))
                }
                
                if post.isSpoiler {
                    Text("SPOILER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 3))
                }
                
                // Domain indicator for links
                if post.postType == .link && !(post.domain?.isEmpty ?? true) {
                    Text(shortenedDomain)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
                    selectedPost: $selectedPost
                )
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
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
                .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var linkPostContent: some View {
        if let urlString = post.url {
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
            
            if post.gilded > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "seal.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    
                    if post.gilded > 1 {
                        Text("\(post.gilded)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if post.locked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            if post.archived {
                Image(systemName: "archivebox.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var bottomActionToolbar: some View {
        HStack(spacing: 0) {
            // PROMINENT Vote cluster - properly centered
            HStack(spacing: 8) {
                Button(action: {
                    handleVote(voteState == .upvoted ? .neutral : .upvoted)
                }) {
                    Image(systemName: voteState == .upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.title3)
                        .foregroundStyle(voteState == .upvoted ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: voteState)
                .disabled(isVoting)
                
                // Centered score with smart animation
                Text(scoreText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)
                    .monospacedDigit()
                    .contentTransition(shouldAnimateScore ? .numericText() : .identity)
                    .frame(minWidth: 32) // Ensure consistent width
                
                Button(action: {
                    handleVote(voteState == .downvoted ? .neutral : .downvoted)
                }) {
                    Image(systemName: voteState == .downvoted ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(voteState == .downvoted ? .purple : .secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: voteState)
                .disabled(isVoting)
            }
            
            Spacer()
            
            // Comments
            Button(action: {
                // TODO: Navigate to comments
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                    Text(post.commentsText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Spacer().frame(width: 16)
            
            // More menu
            MoreMenuViewCompact(
                post: currentPost,
                onShare: handleShare,
                onSave: handleSave,
                onCopyLink: handleCopyLink,
                onOpenOriginal: handleOpenOriginal
            )
        }
        .padding(.top, 8)
    }
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted: return .blue
        case .downvoted: return .purple
        case .neutral: return .primary
        }
    }
    
    // Only animate score if the change would be visible to users
    private var shouldAnimateScore: Bool {
        return displayScore < 1000 // Only animate for scores under 1k where single changes are visible
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
        let activityVC = UIActivityViewController(
            activityItems: [post.permalinkURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
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

