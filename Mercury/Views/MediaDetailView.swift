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

struct MediaDetailView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    @State private var player: AVPlayer?
    @State private var hasAppeared = false
    @State private var isContentVisible = true
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false

    init(post: RedditPost, namespace: Namespace.ID) {
        self.post = post
        self.namespace = namespace
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            mediaContent
                .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            
            // Overlay container that handles taps
            VStack {
                if isContentVisible {
                    topNavigationBar
                        .transition(.opacity)
                }
                
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
        .preferredColorScheme(.dark)
        .onAppear {
            print("🎬 MediaDetailView appeared for: \(post.title)")
            hasAppeared = true
        }
        .onDisappear {
            print("🎬 MediaDetailView disappeared for: \(post.title)")
            if let player = player {
                player.pause()
                player.seek(to: .zero)
                self.player = nil
            }
        }
    }
    
    private var topNavigationBar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: handleShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44) // Proper touch target
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Share")
                
                Button(action: handleSave) {
                    Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44) // Proper touch target
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(post.saved ? "Unsave" : "Save")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .clipped()
        )
    }
    
    private var bottomContentOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Post context
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        navigationPath.navigate(to: .subredditFeed(subreddit: post.subreddit))
                        dismiss()
                    }) {
                        Text(post.displaySubreddit)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        navigationPath.navigate(to: .userProfile(username: post.author))
                        dismiss()
                    }) {
                        Text("u/\(post.author)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("•")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    
                    Text(post.timeAgo)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                
                Text(post.title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            
            // Action bar
            HStack(spacing: 24) {
                // Vote controls
                HStack(spacing: 12) {
                    Button(action: {
                        handleVote(voteState == .upvoted ? .neutral : .upvoted)
                    }) {
                        Image(systemName: voteState == .upvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .font(.title3)
                            .foregroundStyle(voteState == .upvoted ? .blue : .white)
                    }
                    .disabled(isVoting)
                    
                    Text(scoreText)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    
                    Button(action: {
                        handleVote(voteState == .downvoted ? .neutral : .downvoted)
                    }) {
                        Image(systemName: voteState == .downvoted ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .font(.title3)
                            .foregroundStyle(voteState == .downvoted ? .purple : .white)
                    }
                    .disabled(isVoting)
                }
                
                Spacer()
                
                // Comments
                Button(action: {
                    // TODO: Navigate to comments
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.callout)
                        Text(post.commentsText)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .clipped()
        )
    }
    
    private var mediaId: String {
        "\(post.id)-\(post.postType.displayName.lowercased())"
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
                            .onTapGesture {
                                dismiss()
                            }
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
                    .onTapGesture {
                        dismiss()
                    }
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
    
    private var scoreColor: Color {
        switch voteState {
        case .upvoted: return .blue
        case .downvoted: return .purple
        case .neutral: return .white
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
                } else {
                    try await redditAPI.savePost(postId: post.id)
                }
            } catch {
                print("Save/Unsave error: \(error)")
            }
        }
    }

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
