//
//  GalleryView.swift
//  Mercury
//
//

import SwiftUI
import Nuke
import NukeUI
import Zoomable
import Defaults

// MARK: - Gallery View for Feed
struct SimpleGalleryView: View {
    let post: RedditPost
    let mediaId: String
    let namespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    
    @State private var isLoaded = false
    @State private var isBlurred = false
    
    private var galleryImages: [GalleryImage] {
        return post.galleryImages
    }
    
    private var firstImage: GalleryImage? {
        return galleryImages.first
    }
    
    private var displayHeight: CGFloat {
        guard let firstImage = firstImage else { return 300 }
        let dims = CGSize(width: CGFloat(firstImage.width), height: CGFloat(firstImage.height))
        return MediaLayout.height(for: dims, maxHeight: 600, fallback: 300)
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
                .overlay(alignment: .bottomTrailing) {
                    // Gallery badge with count
                    galleryBadge
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .matchedTransitionSource(id: mediaId, in: namespace)
        .sensitiveContentBlurred(post: post, contentType: .gallery, isBlurred: $isBlurred)
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
