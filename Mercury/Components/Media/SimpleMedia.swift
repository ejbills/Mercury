import SwiftUI
import Nuke
import NukeUI
import AVKit
import AVFoundation
import Defaults
 

// MARK: - Simple Image View
struct SimpleImageView: View {
    let url: String
    let mediaId: String
    let title: String?
    let namespace: Namespace.ID
    let apiDimensions: CGSize? // API-provided dimensions
    let post: RedditPost
    @Binding var selectedPost: RedditPost?
    @State private var isLoaded = false
    @State private var isBlurred = false
    @State private var loadedDimensions: CGSize? = nil
    
    private let fallbackHeight: CGFloat = 300
    
    private var effectiveDimensions: CGSize? {
        loadedDimensions ?? apiDimensions
    }
    
    private var resolvedAspectRatio: CGFloat {
        guard let dims = effectiveDimensions, dims.width > 0, dims.height > 0 else {
            // Default to 4:3 when we have no intrinsic size yet
            return 4.0 / 3.0
        }
        let ratio = dims.width / dims.height
        return ratio > 0 ? ratio : 4.0 / 3.0
    }
    
    var body: some View {
        let mediaContent = LazyImage(url: URL(string: url)) { state in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
                
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isLoaded ? 1 : 0)
                        .onAppear {
                            if let container = state.imageContainer, loadedDimensions != container.image.size {
                                loadedDimensions = container.image.size
                            }
                            if !isLoaded {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoaded = true
                                }
                            }
                        }
                } else if state.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Failed to load image")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
        }
        .processors([.resize(size: CGSize(width: 800, height: 600), contentMode: .aspectFit)]) // Resize for consistent caching
        .priority(.high) // High priority loading
        .transition(.opacity) // Smooth transition only
        
        Group {
            if effectiveDimensions == nil {
                mediaContent
                    .frame(minHeight: fallbackHeight)
                    .aspectRatio(resolvedAspectRatio, contentMode: .fit)
            } else {
                mediaContent
                    .aspectRatio(resolvedAspectRatio, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selectedPost = post }
        .matchedTransitionSource(id: mediaId, in: namespace)
        .sensitiveContentBlurred(post: post, contentType: .image, isBlurred: $isBlurred)
    }
}

// MARK: - Simple GIF View
struct SimpleGifView: View {
    let url: URL
    let mediaId: String
    let title: String?
    let namespace: Namespace.ID
    let post: RedditPost
    @Binding var selectedPost: RedditPost?
    
    @State private var isLoaded = false
    @State private var isBlurred = false
    
    
    private var displayHeight: CGFloat {
        let apiDims = post.imageDimensions ?? post.videoThumbnailDimensions
        return MediaLayout.height(for: apiDims, maxHeight: 600, fallback: 300)
    }
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
            .overlay {
                FLAnimatedGifView(
                    url: url,
                    contentMode: .fill,
                    cornerRadius: 12,
                    fixedHeight: displayHeight
                )
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight)
            }
            
            .opacity(isLoaded ? 1 : 0)
            .onAppear {
                if !isLoaded {
                    withAnimation(.easeOut(duration: 0.3)) { isLoaded = true }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedPost = post }
            .matchedTransitionSource(id: mediaId, in: namespace)
            .sensitiveContentBlurred(post: post, contentType: .gif, isBlurred: $isBlurred)
    }
}

// MARK: - Simple Video View - EXPLICIT HANDOFF
struct SimpleVideoView: View {
    let videoURL: String
    let thumbnailURL: String?
    let mediaId: String
    let title: String?
    let namespace: Namespace.ID
    let apiDimensions: CGSize?
    let post: RedditPost
    let onRequestDetail: (VideoHandoffState) -> Void
    let resumeFromState: VideoHandoffState?
    
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var isMuted: Bool = true
    @State private var isLoading: Bool = true
    @State private var showThumbnail: Bool = true
    @State private var isBlurred = false
    @State private var inlineCurrentTime: Double = 0
    @State private var inlineAVPlayer: AVPlayer? = nil
    @State private var reloadToken: Int = 0
    @State private var loadFailed: Bool = false
    
    private var displayHeight: CGFloat {
        MediaLayout.height(for: apiDimensions, maxHeight: 600, fallback: 300)
    }
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
            .overlay(alignment: .center) {
                ZStack {
                    // Background thumbnail or placeholder while loading
                    if showThumbnail {
                        thumbnailView
                    } else {
                        placeholder
                    }

                    // Player on top when URL is valid
                    if let u = URL(string: videoURL) {
                        NukeVideoPlayer(
                            url: u,
                            cornerRadius: 12,
                            isLooping: true,
                            gravity: .resizeAspectFill,
                            onReady: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isLoading = false
                                    showThumbnail = false
                                    loadFailed = false
                                }
                            },
                            onError: { err in
                                if let err = err {
                                    print("[Video] Failed to load: \(videoURL) — \(err.localizedDescription)")
                                } else {
                                    print("[Video] Failed to load: \(videoURL) — unknown error")
                                }
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isLoading = false
                                    // Show the placeholder with failure message
                                    showThumbnail = false
                                    loadFailed = true
                                }
                            },
                            onPlayerAvailable: { p in
                                inlineAVPlayer = p
                                p.isMuted = isMuted
                            },
                            onTimeUpdate: { t in inlineCurrentTime = t },
                            resumeTime: resumeFromState?.currentTime,
                            resumeMuted: resumeFromState?.isMuted,
                            reloadToken: reloadToken
                        )
                        .frame(height: displayHeight)
                    }

                    if isLoading {
                        loadingOverlay
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                muteButton.padding(4)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
            .matchedTransitionSource(id: mediaId, in: namespace)
            .sensitiveContentBlurred(post: post, contentType: .video, isBlurred: $isBlurred)
            .onChange(of: resumeFromState) { _, _ in }
            .onDisappear {
                // Ensure audio never bleeds when navigating away
                inlineAVPlayer?.applyMuteState(muted: true)
                player?.applyMuteState(muted: true)
                isMuted = true
            }
            
    }
    
    private var thumbnailView: some View {
        Group {
            if let thumbnailURL = thumbnailURL {
                LazyImage(url: URL(string: thumbnailURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: displayHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholder
                    }
                }
                .processors([.resize(size: CGSize(width: 800, height: 600))])
                .priority(.high)
            } else {
                placeholder
            }
        }
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "video")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(loadFailed ? "Failed to load video" : "Loading video…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var muteButton: some View {
        Pill(action: toggleMute, size: .regular) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.caption)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
            ProgressView()
        }
    }
    
    private func setupVideo() {
        guard let url = URL(string: videoURL) else { return }
        
        player = AVPlayer(url: url)
        
        if let player = player {
            player.applyMuteState(muted: isMuted)
            
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { time in
                Task { @MainActor in
                    if time.seconds > 0.1 {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isLoading = false
                            showThumbnail = false
                        }
                    }
                }
            }
            
            player.play()
            isLoading = player.currentTime().seconds <= 0.1
        }
    }
    
    private func teardownVideo() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        player?.pause()
        player = nil
        showThumbnail = true
    }
    
    private func handleTap() {
        guard let url = URL(string: videoURL) else { return }
        if let p = inlineAVPlayer { p.pause() }
        let handoffPlayer = inlineAVPlayer ?? AVPlayer(url: url)
        let handoffState = VideoHandoffState(
            postId: post.id,
            videoURL: url,
            currentTime: inlineCurrentTime,
            isMuted: isMuted,
            player: handoffPlayer
        )
        onRequestDetail(handoffState)
    }
    
    private func resumeFromExplicitState(_ state: VideoHandoffState) {
        player = state.player
        
        state.applyTo(state.player)
        isMuted = state.isMuted
        state.player.play()
        isLoading = false
        showThumbnail = false
        
  
        
        if timeObserver == nil {
            timeObserver = state.player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { time in
                Task { @MainActor in
                    if time.seconds > 0.1 && isLoading {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        // Apply to inline NukeVideo-backed player if present
        inlineAVPlayer?.applyMuteState(muted: isMuted)
        // Also apply to legacy/local player if present (detail handoff compatibility)
        player?.applyMuteState(muted: isMuted)
    }

    private func retryPlayback() {
        // Force reload
        isLoading = true
        showThumbnail = true
        inlineAVPlayer?.pause()
        inlineAVPlayer = nil
        reloadToken &+= 1 // wraparound-safe increment
    }
}

// MARK: - Simple External Video View (Streamable, Twitch, etc.)
struct SimpleExternalVideoView: View {
    let externalURL: String
    let thumbnailURL: String?
    let apiDimensions: CGSize?
    let domain: String?
    let post: RedditPost
    let onTap: () -> Void

    @State private var isLoaded = false
    @State private var isBlurred = false

    private var displayHeight: CGFloat {
        MediaLayout.height(for: apiDimensions, maxHeight: 600, fallback: 300)
    }

    private var domainLabel: String {
        guard let domain = domain else { return "External Video" }
        if domain.contains("streamable") { return "Streamable" }
        if domain.contains("twitch") { return "Twitch" }
        if domain.contains("vimeo") { return "Vimeo" }
        return domain
    }

    var body: some View {
        Button(action: onTap) {
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight)
                .overlay {
                    thumbnailView
                }
                .overlay {
                    // Play button overlay
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 64, height: 64)

                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.primary)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // Domain badge
                    Pill(size: .small) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                            Text(domainLabel)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(10)
                    .opacity(isLoaded ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sensitiveContentBlurred(post: post, contentType: .video, isBlurred: $isBlurred)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL = thumbnailURL {
            LazyImage(url: URL(string: thumbnailURL)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: displayHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isLoaded ? 1 : 0)
                        .onAppear {
                            if !isLoaded {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoaded = true
                                }
                            }
                        }
                } else if state.error != nil {
                    placeholder
                } else {
                    placeholder
                        .overlay {
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                }
            }
            .processors([.resize(size: CGSize(width: 800, height: 600))])
            .priority(.high)
        } else {
            placeholder
                .onAppear {
                    if !isLoaded {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isLoaded = true
                        }
                    }
                }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
    }
}
