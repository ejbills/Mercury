//
//  RedditPostCard.swift
//  Mercury
//
//

import SwiftUI
import Nuke
import NukeUI

struct RedditPostCard: View {
    let url: String
    let onTap: (RedditPost?) -> Void
    
    @State private var redditPost: RedditPost?
    @State private var isLoading = true
    
    var body: some View {
        EmbedCard(
            thumbnail: thumbnailView,
            labelIcon: "r.circle.fill",
            labelText: "Reddit Post",
            labelTint: .secondary,
            title: displayTitle,
            subtitle: displaySubreddit,
            onTap: { onTap(redditPost) }
        )
        .task { await loadRedditPost() }
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
            .fill(.fill.secondary)
            .frame(width: EmbedCardMetrics.thumbnailSize, height: EmbedCardMetrics.thumbnailSize)
            .overlay {
                Image(systemName: "r.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
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
