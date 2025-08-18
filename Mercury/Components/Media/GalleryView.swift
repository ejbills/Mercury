//
//  GalleryView.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI
import Nuke
import NukeUI
import Zoomable

// MARK: - Gallery View for Feed
struct SimpleGalleryView: View {
    let post: RedditPost
    let mediaId: String
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    
    @State private var isLoaded = false
    
    private var galleryImages: [GalleryImage] {
        return post.galleryImages
    }
    
    private var firstImage: GalleryImage? {
        return galleryImages.first
    }
    
    private var displayHeight: CGFloat {
        guard let firstImage = firstImage else { return 300 }
        
        let screenWidth = UIScreen.main.bounds.width - 24 // Account for padding
        let aspectRatio = CGFloat(firstImage.width) / CGFloat(firstImage.height)
        let calculatedHeight = screenWidth / aspectRatio
        return min(calculatedHeight, 600) // Max height cap same as regular images
    }
    
    var body: some View {
        Button(action: { selectedPost = post }) {
            // FIXED FRAME CONTAINER - NEVER CHANGES SIZE
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight) // FIXED HEIGHT FROM API
                .overlay {
                    if let firstImage = firstImage {
                        LazyImage(url: URL(string: firstImage.url)) { state in
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
                                Rectangle()
                                    .fill(.quaternary.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: displayHeight)
                                    .overlay {
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.stack")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.secondary)
                                            Text("Failed to load gallery")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                            } else {
                                // Loading placeholder maintains exact same size
                                Rectangle()
                                    .fill(.quaternary.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: displayHeight)
                                    .overlay {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    }
                            }
                        }
                        .processors([.resize(size: CGSize(width: 800, height: 600))]) // Resize for consistent caching
                        .priority(.high) // High priority loading
                        .transition(.opacity) // Smooth transition only
                    }
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    // Gallery badge with count
                    galleryBadge
                }
        }
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
    }
    
    private var galleryBadge: some View {
        Pill(size: .small) {
            HStack(spacing: 4) {
                Image(systemName: "photo.stack.fill")
                    .font(.caption2)
                
                Text("\(galleryImages.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .padding(10)
        .opacity(isLoaded ? 1 : 0)
    }
}

// MARK: - Gallery Detail View with Pagination
struct GalleryDetailView: View {
    let post: RedditPost
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.redditAPI) private var redditAPI
    @State private var currentIndex = 0
    @State private var voteState: RedditPost.VoteState
    @State private var displayScore: Int
    @State private var isVoting = false
    @State private var shareItem: URL?
    @State private var shareItems: [URL]?
    @State private var showShareSheet = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    private var galleryImages: [GalleryImage] {
        return post.galleryImages
    }
    
    
    private var currentPost: RedditPost {
        var updatedPost = post
        updatedPost.currentVoteState = voteState
        updatedPost.displayScore = displayScore
        return updatedPost
    }
    
    init(post: RedditPost, namespace: Namespace.ID) {
        self.post = post
        self.namespace = namespace
        self._voteState = State(initialValue: post.currentVoteState)
        self._displayScore = State(initialValue: post.displayScore)
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Main gallery content with TabView
            TabView(selection: $currentIndex) {
                ForEach(0..<galleryImages.count, id: \.self) { imageIndex in
                    LazyImage(url: URL(string: galleryImages[imageIndex].url)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(1.0) // Remove zoomable to allow TabView swiping
                                .onTapGesture(count: 2) {
                                    // Double-tap to zoom can be added later if needed
                                }
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
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            
            // UI overlay
            VStack {
                Spacer()
                
                // Bottom content overlay
                bottomContentOverlay
            }
            
            // Download progress overlay
            if isDownloading {
                downloadProgressOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if let shareItems = shareItems {
                MediaShareSheet(post: post, mediaURLs: shareItems)
            } else {
                MediaShareSheet(post: post, mediaURL: shareItem)
            }
        }
    }
    
    private var mediaId: String {
        "\(post.id)-gallery"
    }
    
    private var bottomContentOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Image counter overlay with Pill styling
            HStack {
                Spacer()
                Pill(size: .small) {
                    Text("\(currentIndex + 1) of \(galleryImages.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                Spacer()
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
            
            // Action toolbar
            PostActionToolbar(
                post: currentPost,
                voteState: $voteState,
                displayScore: $displayScore,
                isVoting: $isVoting,
                onVote: handleVote,
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
            .frame(height: 180)
            .clipped()
        )
    }
    
    @ViewBuilder
    private var downloadProgressOverlay: some View {
        ZStack {
            Color(UIColor.systemBackground).opacity(0.9)
            
            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                VStack(spacing: 4) {
                    Text("Downloading Image")
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
        guard !isDownloading else { return }
        
        isDownloading = true
        Task {
            defer { isDownloading = false }
            do {
                let service = MediaDownloadService()
                // Download all gallery images
                let fileURLs = try await service.downloadAllGalleryImages(post: post, options: .init(
                    preferredFilename: post.id,
                    onProgress: { progress in
                        Task { @MainActor in
                            downloadProgress = progress
                        }
                    }
                ))
                await MainActor.run {
                    // Use the new multiple URLs share sheet
                    shareItems = fileURLs
                    shareItem = nil
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
}

#Preview {
    @Previewable @Namespace var namespace
    
    NavigationStack {
        SimpleGalleryView(
            post: RedditPost.samplePost,
            mediaId: "sample-gallery",
            namespace: namespace,
            selectedPost: .constant(nil)
        )
    }
}
