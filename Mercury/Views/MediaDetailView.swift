//
//  MediaDetailView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import AVKit
import Nuke
import NukeUI
import UIKit
import Zoomable

struct MediaDetailView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    @Environment(\.colorScheme) private var colorScheme
    @State private var player: AVPlayer?
    @State private var hasAppeared = false
    @State private var isContentVisible = true
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    @State private var shareItem: URL?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showShareSheet = false
    @State private var showingPostReply = false

    init(post: RedditPost, namespace: Namespace.ID) {
        self.post = post
        self.namespace = namespace
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
    }
    
    private var currentPost: RedditPost {
        var updatedPost = post
        updatedPost.currentVoteState = voteState
        updatedPost.displayScore = displayScore
        return updatedPost
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            mediaContent
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
                .overlay {
                    if isDownloading {
                        downloadProgressOverlay
                    }
                }
            
            // Overlay container that handles taps
            VStack {
                Spacer()
                
                if isContentVisible {
                    bottomContentOverlay
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isContentVisible)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isContentVisible.toggle()
                }
            }
            .allowsHitTesting(isContentVisible) // Only allow taps when overlays are visible
        }
        .navigationBarHidden(true)
        .statusBarHidden(!isContentVisible)

        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            if let player = player {
                player.pause()
                player.seek(to: .zero)
                self.player = nil
            }
        }
    }
    
    
    private var bottomContentOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Post context
            VStack(alignment: .leading, spacing: 8) {
                PostHeader(post: post, colorScheme: .dark)
                
                Text(post.title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            
            // Action bar matching post layout exactly
            PostActionToolbar(
                post: currentPost,
                voteState: $voteState,
                displayScore: $displayScore,
                isVoting: $isVoting,
                onVote: handleVote,
                onReply: { showingPostReply = true },
                onShare: handleShare,
                onSave: handleSave,
                onCopyLink: nil,
                onOpenOriginal: nil,
                onCommentsAction: nil,
                onDownload: handleDownload,
                colorScheme: .dark,
                size: .compact
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .clipped()
        )
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
    }
    
    private var mediaId: String {
        "\(post.id)-\(post.postType.displayName.lowercased())"
    }

    private func submitRootReply(text: String) async throws {
        let parent = "t3_\(post.id)"
        _ = try await redditAPI.submitComment(parentFullname: parent, text: text)
    }
    
    @ViewBuilder
    private var mediaContent: some View {
        switch post.postType {
        case .image:
            if let imageURL = post.imageURL {
                LazyImage(url: URL(string: imageURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zoomable()
                    } else if state.error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                            Text("Failed to load image")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
            
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                AnimatedGifView(url: url, contentMode: .scaleAspectFit, cornerRadius: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zoomable()
            }
            
        case .video:
            if let videoURL = post.videoURL, let url = URL(string: videoURL) {
                VideoPlayer(player: player ?? AVPlayer(url: url))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: url)
                        }
                        // Auto-play when appearing
                        player?.play()
                    }
                    .onTapGesture {
                        // Let video player handle its own controls
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text("Failed to load video")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        case .gallery:
            // Gallery posts should use GalleryDetailView instead
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("Gallery view not available")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        case .text, .link:
            // These shouldn't appear in media detail view
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("Content not available in media view")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Computed Properties
    
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
        // Simple share always shares the post URL, not the media
        // Media sharing is handled by the download button
        shareItem = nil  // No media file to share
        showShareSheet = true
    }
    
    private func handleSave() {
        Task {
            do {
                if post.saved {
                    try await redditAPI.unsavePost(postId: post.id)
                } else {
                    try await redditAPI.savePost(postId: post.id)
                }
            } catch {
                print("Save/Unsave error: \(error)")
            }
        }
    }

    private func handleDownload() {
        guard post.postType == .video || post.postType == .gif || post.postType == .image || post.postType == .gallery else { return }
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
                    // Fallback to sharing the post URL
                    shareItem = URL(string: post.permalinkURL)
                    showShareSheet = true
                }
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

struct MediaDetailShareableItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct MediaItem: Identifiable, Hashable {
    let id: String
    let type: MediaType
    let title: String?
    
    enum MediaType: Hashable {
        case image(url: String)
        case gif(url: URL)
        case video(url: String, thumbnailURL: String?)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    
    NavigationStack {
        MediaDetailView(
            post: RedditPost.samplePost,
            namespace: namespace
        )
        .environment(\.redditAPI, RedditAPIManager())
    }
}
