//
//  SimpleMedia.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI

// MARK: - Simple Image View
struct SimpleImageView: View {
    let url: String
    let mediaId: String
    let title: String?
    let namespace: Namespace.ID
    let apiDimensions: CGSize? // API-provided dimensions
    let post: RedditPost
    
    @State private var isLoaded = false
    
    private var displayHeight: CGFloat {
        guard let apiDimensions = apiDimensions else { return 300 } // Fallback
        
        let screenWidth = UIScreen.main.bounds.width - 24 // Account for padding
        let aspectRatio = apiDimensions.width / apiDimensions.height
        let calculatedHeight = screenWidth / aspectRatio
        return min(calculatedHeight, 600) // Max height cap
    }
    
    var body: some View {
        NavigationLink(value: post) {
            // FIXED FRAME CONTAINER - NEVER CHANGES SIZE
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight) // FIXED HEIGHT FROM API
                .overlay {
                    LazyImage(url: URL(string: url)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: displayHeight)
                                .clipped()
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
            .background(.quaternary.opacity(0.1))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    @State private var isLoaded = false
    
    var body: some View {
        NavigationLink(value: post) {
            AnimatedGifCard(url: url, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 600)
                .clipped()
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
    }
}

// MARK: - Simple Video View
struct SimpleVideoView: View {
    let videoURL: String
    let thumbnailURL: String?
    let mediaId: String
    let title: String?
    let namespace: Namespace.ID
    let apiDimensions: CGSize? // API-provided dimensions
    let post: RedditPost
    
    @State private var isLoaded = false
    
    private var displayHeight: CGFloat {
        guard let apiDimensions = apiDimensions else { return 300 } // Fallback
        
        let screenWidth = UIScreen.main.bounds.width - 24 // Account for padding
        let aspectRatio = apiDimensions.width / apiDimensions.height
        let calculatedHeight = screenWidth / aspectRatio
        return min(calculatedHeight, 600) // Max height cap
    }
    
    var body: some View {
        NavigationLink(value: post) {
            // FIXED FRAME CONTAINER - NEVER CHANGES SIZE
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: displayHeight) // FIXED HEIGHT FROM API
                .overlay {
                    ZStack {
                        // Video thumbnail with aggressive caching
                        Group {
                            if let thumbnailURL = thumbnailURL {
                                LazyImage(url: URL(string: thumbnailURL)) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill) // Use fill to maintain container size
                                            .frame(maxWidth: .infinity)
                                            .frame(height: displayHeight)
                                            .clipped()
                                    } else {
                                        // Placeholder maintains exact same size
                                        Rectangle()
                                            .fill(.quaternary.opacity(0.3))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: displayHeight)
                                            .overlay {
                                                videoPlaceholderContent
                                            }
                                    }
                                }
                                .processors([.resize(size: CGSize(width: 800, height: 600))]) // Resize for consistent caching
                                .priority(.high) // High priority loading
                                .transition(.opacity) // Smooth transition only
                            } else {
                                // No thumbnail - fixed placeholder
                                Rectangle()
                                    .fill(.quaternary.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: displayHeight)
                                    .overlay {
                                        videoPlaceholderContent
                                    }
                            }
                        }
                        .background(.quaternary.opacity(0.1))
                        
                        // Apple-style play button overlay
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.primary)
                                    .offset(x: 2)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
    }
    
    private var videoPlaceholderContent: some View {
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
