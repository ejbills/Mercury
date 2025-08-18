//
//  RedditPostCard.swift
//  Mercury
//
//  Created by AI Assistant on 8/18/25.
//

import SwiftUI
import Nuke
import NukeUI

struct RedditPostCard: View {
    let url: String
    let onTap: () -> Void
    
    @State private var redditPost: RedditPost?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 12) {
            // Reddit icon/thumbnail on left
            thumbnailView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                // Reddit post indicator
                HStack(spacing: 6) {
                    Image(systemName: "r.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Text("REDDIT POST")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 14)
                
                // Post title
                Text(displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(redditPost?.title != nil ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 32)
                
                // Subreddit info
                Text(displaySubreddit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await loadRedditPost()
        }
    }
    
    // MARK: - Computed Properties
    
    private var thumbnailView: some View {
        Group {
            if let post = redditPost,
               let thumbnailURL = extractThumbnailURL(from: post) {
                LazyImage(url: URL(string: thumbnailURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                    } else {
                        redditPlaceholder
                    }
                }
                .processors([.resize(size: CGSize(width: 120, height: 120))])
                .priority(.high)
                .transition(.opacity)
            } else {
                redditPlaceholder
            }
        }
    }
    
    private var displayTitle: String {
        if let title = redditPost?.title, !title.isEmpty {
            return title
        } else if isLoading {
            return "Loading Reddit post..."
        } else {
            return "Reddit Post"
        }
    }
    
    private var displaySubreddit: String {
        if let subreddit = redditPost?.subreddit, !subreddit.isEmpty {
            return "r/\(subreddit)"
        }
        // Fallback to URL parsing
        if url.contains("/r/") {
            let components = url.components(separatedBy: "/r/")
            if components.count > 1 {
                let subredditPart = components[1].components(separatedBy: "/").first ?? ""
                return "r/\(subredditPart)"
            }
        }
        return "Reddit"
    }
    
    private var redditPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.orange.opacity(0.1))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "r.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
    }
    
    private func loadRedditPost() async {
        Task.detached(priority: .utility) { [url] in
            let fetchedPost = await RedditPostFetchService.shared.fetchPost(from: url)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.redditPost = fetchedPost
                    self.isLoading = false
                }
            }
        }
    }
    
    private func extractThumbnailURL(from post: RedditPost) -> String? {
        // Try preview images first (best quality)
        if let preview = post.preview,
           !preview.images.isEmpty,
           let firstImage = preview.images.first {
            let source = firstImage.source
            if !source.url.isEmpty {
                return source.url.replacingOccurrences(of: "&amp;", with: "&")
            }
        }
        
        // Try thumbnail if available and not default/self
        if let thumbnail = post.thumbnail,
           !thumbnail.isEmpty,
           !thumbnail.contains("self"),
           !thumbnail.contains("default"),
           thumbnail.hasPrefix("http") {
            return thumbnail
        }
        
        // Try post URL if it's an image
        if let postURL = post.url,
           (postURL.contains("i.redd.it") || postURL.contains("i.imgur.com")) {
            return postURL
        }
        
        return nil
    }
}

#Preview {
    VStack(spacing: 16) {
        RedditPostCard(
            url: "https://reddit.com/r/SwiftUI/comments/123456/sample_post_title",
            onTap: {}
        )
        
        RedditPostCard(
            url: "https://redd.it/abc123",
            onTap: {}
        )
    }
    .padding()
}