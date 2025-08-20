//
//  SimpleMedia.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI
import AVKit
import AVFoundation
 

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
    
    private var displayHeight: CGFloat {
        MediaLayout.height(for: apiDimensions, maxHeight: 600, fallback: 300)
    }
    
    var body: some View {
        Button(action: { selectedPost = post }) {
            // FIXED FRAME CONTAINER - NEVER CHANGES SIZE
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight) // FIXED HEIGHT FROM API
                .overlay(alignment: .center) {
                    LazyImage(url: URL(string: url)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: displayHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .opacity(isLoaded ? 1 : 0)
                                .onAppear {
                                    // Only animate when image actually loads
                                    if !isLoaded {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            isLoaded = true
                                        }
                                    }
                                }
                        } else if state.error != nil {
                            // Error placeholder maintains exact same size
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: displayHeight)
                                .overlay(alignment: .center) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.secondary)
                                        Text("Failed to load image")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        } else {
                            // Loading placeholder maintains exact same size
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: displayHeight)
                                .overlay(alignment: .center) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                }
                        }
                    }
                                    .processors([.resize(size: CGSize(width: 800, height: 600))]) // Resize for consistent caching
                .priority(.high) // High priority loading
                .transition(.opacity) // Smooth transition only
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
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
    
    var body: some View {
        Button(action: { selectedPost = post }) {
            AnimatedGifCard(url: url, cornerRadius: 12)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 600)
                .opacity(isLoaded ? 1 : 0)
                .onAppear {
                    // Only animate when GIF actually loads, not on appear
                    if !isLoaded {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isLoaded = true
                        }
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
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
                    // Background thumbnail
                    if showThumbnail { thumbnailView }
                    
                    // Video player
                    if let player = player {
                        SimpleVideoPlayer(
                            player: player,
                            showControls: false,
                            shouldLoop: true,
                            autoPlay: true,
                        )
                        .frame(height: displayHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
            .onAppear { setupVideo() }
            .onDisappear { teardownVideo() }
            .matchedTransitionSource(id: mediaId, in: namespace)
            .overlay(alignment: .center) {
                if isLoading { loadingOverlay }
            }
            .overlay(alignment: .topTrailing) {
                muteButton.padding(4)
            }
            .onChange(of: resumeFromState) { _, newState in
                if let state = newState {
                    resumeFromExplicitState(state)
                }
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
                    Text("Video")
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
        
        // Create individual player (no more shared pool!)
        player = AVPlayer(url: url)
        
        if let player = player {
            player.applyMuteState(muted: isMuted)
            
            // Add time observer for loading state only
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
        
        // Clean shutdown - pause and clear player
        player?.pause()
        player = nil
        showThumbnail = true
    }
    
    private func handleTap() {
        guard let player = player, let url = URL(string: videoURL) else { return }
        
        // Create explicit handoff state using our local muted state, not player state
        let handoffState = VideoHandoffState(
            postId: post.id, 
            videoURL: url, 
            currentTime: player.currentTime().seconds,
            isMuted: isMuted,  // Use local state, not player state
            player: player
        )
        
        // Pause inline player
        player.pause()
        
        // Request detail with explicit state
        onRequestDetail(handoffState)
    }
    
    private func resumeFromExplicitState(_ state: VideoHandoffState) {
        // Use the same player instance from handoff
        player = state.player
        
        // Apply the final state and sync local state
        state.applyTo(state.player)
        isMuted = state.isMuted
        // Resume playback
        state.player.play()
        isLoading = false
        showThumbnail = false
        
  
        
        // Re-add time observer
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
        player?.applyMuteState(muted: isMuted)
        // Note: Mute state is maintained locally and passed through handoff
    }
}
