// MediaDetailView.swift
// Mercury

import SwiftUI
import UIKit
import AVKit
import AVFoundation

import Nuke
import NukeUI
import UIKit
import Zoomable

struct MediaDetailView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    let videoHandoffState: VideoHandoffState?
    let onVideoHandoffReturn: ((VideoHandoffState) -> Void)?
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
    @State private var savedState: Bool
    @State private var originalMuteState: Bool = true
    @State private var shareItem: URL?
    @State private var shareItems: [URL]?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showShareSheet = false
    @State private var showingPostReply = false
    @State private var currentGalleryIndex = 0
    @State private var gifProgress: Double = 0 // 0..1 for GIF scrubbing
    @State private var isScrubbingGestureActive: Bool = false

    init(post: RedditPost, namespace: Namespace.ID, videoHandoffState: VideoHandoffState? = nil, onVideoHandoffReturn: ((VideoHandoffState) -> Void)? = nil) {
        self.post = post
        self.namespace = namespace
        self.videoHandoffState = videoHandoffState
        self.onVideoHandoffReturn = onVideoHandoffReturn
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
        self._savedState = State(initialValue: post.saved)
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
            
            Group {
                if post.postType != .video {
                    mediaContent
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isContentVisible.toggle()
                            }
                        }
                } else {
                    mediaContent
                }
            }
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
                .overlay {
                    if isDownloading {
                        downloadProgressOverlay
                    }
                }
            
            
            
        }
        .overlay(bottomOverlay, alignment: .bottom)
        .navigationBarHidden(true)
        .statusBarHidden(!isContentVisible)
        .onAppear { hasAppeared = true }
        .onDisappear {
            // Force mute to avoid audio bleeding when navigating away
            player?.applyMuteState(muted: true)

            // Return handoff state to parent if we have video
            if let player = player,
               let handoffState = videoHandoffState,
               let onReturn = onVideoHandoffReturn {
                let currentTime = player.currentTime().seconds
                // Preserve the user's original mute preference in the returned state
                let updatedState = handoffState.updated(time: currentTime, muted: originalMuteState)
                onReturn(updatedState)
            }
            // Clear our reference (but don't destroy the shared player)
            self.player = nil
        }
    }
    
    
    private var bottomContentOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Gallery counter (only for gallery posts)
            if post.postType == .gallery && !post.galleryImages.isEmpty {
                HStack {
                    Spacer()
                    Text("\(currentGalleryIndex + 1) of \(post.galleryImages.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())
                    Spacer()
                }
            }
            
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
                savedState: $savedState,
                onVote: handleVote,
                onReply: { showingPostReply = true },
                onShare: handleShare,
                onSave: handleSave,
                onCopyLink: nil,
                onOpenOriginal: nil,
                onDownload: handleDownload,
                colorScheme: .dark,
                size: .compact
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)
                .offset(y: geometry.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        )
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

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
            Capsule()
                .fill(Color.gray.opacity(0.8))
                .scaleEffect(x: max(0, min(1, gifProgress)), y: 1, anchor: .leading)
        }
        .frame(height: 4)
        .opacity(0.95)
        .animation(.linear(duration: 0.05), value: gifProgress)
    }
    
    private var bottomOverlay: some View {
        Group {
            if isContentVisible, post.postType != .video {
                bottomContentOverlay
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: isContentVisible)
    
                
            }
        }
    }


    private func submitRootReply(text: String) async throws {
        let parent = post.fullname
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
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            }
            
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                    ZStack(alignment: .bottom) {
                        ScrubbableGifView(
                            url: url,
                            contentMode: .fit,
                            cornerRadius: 0,
                            progress: $gifProgress,
                            isScrubbing: isScrubbingGestureActive
                        )
                        .navigationTransition(.zoom(sourceID: mediaId, in: namespace))

                        // Scrubber only at the bottom area to not block other gestures
                        if !isContentVisible {
                            VStack(spacing: 8) {
                                // Let SwiftUI size the bar naturally; just add padding.
                                GeometryReader { geo in
                                    progressBar
                                        .frame(height: 8)
                                        .contentShape(Rectangle())
                                        .highPriorityGesture(
                                            DragGesture(minimumDistance: 2, coordinateSpace: .local)
                                                .onChanged { value in
                                                    // Begin scrubbing only with a drag, not a tap
                                                    if !isScrubbingGestureActive {
                                                        let moved = abs(value.translation.width) > 1 || abs(value.translation.height) > 6
                                                        if !moved { return }
                                                    }
                                                    isScrubbingGestureActive = true
                                                    let width = geo.size.width
                                                    let x = max(0, min(value.location.x, width))
                                                    gifProgress = Double(x / width)
                                                }
                                                .onEnded { _ in
                                                    isScrubbingGestureActive = false
                                                }
                                        )
                                }
                                .frame(height: 8)
                                    
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
            
            }
            
        case .video:
            if let videoURL = post.videoURL, let url = URL(string: videoURL) {
                ZStack {
                    if let p = player {
                        SimpleVideoPlayer(
                            player: p,
                            showControls: true,
                            shouldLoop: false,
                            autoPlay: true,
                            gravity: .resizeAspect
                        )
                    } else {
                        Color.clear
                    }
                }
                .onAppear {
                    if let handoffState = videoHandoffState {
                        // Use handoff player and state
                        player = handoffState.player
                        originalMuteState = handoffState.isMuted
                        handoffState.applyTo(handoffState.player)
                        player?.applyMuteState(muted: false)
                        player?.play()
                    } else {
                        // Fallback: create new player
                        player = AVPlayer(url: url)
                        player?.play()
                    }
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
            if !post.galleryImages.isEmpty {
                TabView(selection: $currentGalleryIndex) {
                    ForEach(0..<post.galleryImages.count, id: \.self) { imageIndex in
                        LazyImage(url: URL(string: post.galleryImages[imageIndex].url)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if state.error != nil {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.stack")
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
                        .tag(imageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text("Gallery is empty")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            }
        case .text, .link, .youtube:
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
        shareItem = nil
        shareItems = nil
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
