//
//  PostRowView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI

struct PostRowView: View {
    let post: RedditPost
    let namespace: Namespace.ID
    @State private var showingSafari = false
    
    // Optimization: compute expensive properties once
    private let postType: PostType
    private let shouldShowLinkPreview: Bool
    
    init(post: RedditPost, namespace: Namespace.ID) {
        self.post = post
        self.namespace = namespace
        self.postType = post.postType
        // Pre-compute expensive shouldShowLinkPreview logic
        self.shouldShowLinkPreview = post.postType == .link && post.url != nil && (
            post.hasContent || (post.thumbnail != nil && 
                               post.thumbnail != "self" && 
                               post.thumbnail != "default" && 
                               post.thumbnail != "nsfw" && 
                               post.thumbnail != "spoiler" &&
                               post.thumbnail != "")
        )
    }
    
    var body: some View {
        MaterialCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header section with better spacing
                VStack(alignment: .leading, spacing: 12) {
                    postHeader
                    postTitle
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                postMediaContent
                
                postFooter
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingSafari) {
            if let urlString = post.url, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
    }
    
    private var postHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Subreddit and badges
            HStack(alignment: .center, spacing: 8) {
                SubredditIcon(
                    iconURL: nil,
                    displayName: post.subreddit,
                    size: 22
                )
                
                Text(post.displaySubreddit)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Badges group
                HStack(spacing: 6) {
                    if post.isPinned || post.isStickied {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    if post.isNsfw {
                        Text("NSFW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    }
                    
                    if post.isSpoiler {
                        Text("SPOILER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            // Bottom row: Author and time in cleaner format
            HStack(spacing: 8) {
                Text("u/\(post.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text(post.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
    }
    
    private var postTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with better typography
            Text(post.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true) // Allow proper text wrapping
            
            // Post type and domain indicator
            HStack(spacing: 8) {
                Label {
                    Text(post.postType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: post.postType.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if post.postType == .link && !(post.domain?.isEmpty ?? true) {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(shortenedDomain)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
                
                Spacer()
            }
        }
    }
    
    private var shortenedDomain: String {
        guard let domain = post.domain else { return "" }
        if domain.hasPrefix("www.") {
            return String(domain.dropFirst(4))
        }
        return domain
    }
    
    @ViewBuilder
    private var postMediaContent: some View {
        switch postType {
        case .text:
            if post.hasContent {
                textPostContent
            }
        case .image:
            if let imageURL = post.imageURL {
                SimpleImageView(
                    url: imageURL,
                    mediaId: "\(post.id)-image",
                    title: post.title,
                    namespace: namespace,
                    apiDimensions: post.imageDimensions
                )
            }
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                SimpleGifView(
                    url: url,
                    mediaId: "\(post.id)-gif",
                    title: post.title,
                    namespace: namespace
                )
            }
        case .video:
            if post.videoURL != nil {
                SimpleVideoView(
                    videoURL: post.videoURL!,
                    thumbnailURL: post.videoThumbnailURL ?? post.imageURL,
                    mediaId: "\(post.id)-video",
                    title: post.title,
                    namespace: namespace,
                    apiDimensions: post.videoThumbnailDimensions
                )
            }
        case .link:
            if shouldShowLinkPreview {
                linkPostContent
            }
        }
    }
    
    @ViewBuilder
    private var textPostContent: some View {
        if let content = post.selftext, !content.isEmpty {
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
                .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var linkPostContent: some View {
        if let urlString = post.url {
            RichArticleCard(
                url: urlString,
                fallbackThumbnail: validThumbnailURL,
                fallbackDomain: post.domain,
                fallbackTitle: post.title
            ) {
                showingSafari = true
            }
        }
    }
    
    private var validThumbnailURL: String? {
        guard let thumbnail = post.thumbnail,
              thumbnail != "self",
              thumbnail != "default", 
              thumbnail != "nsfw",
              thumbnail != "spoiler",
              !thumbnail.isEmpty else {
            return nil
        }
        return thumbnail
    }
    
    private var postFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Flair if available
            if let linkFlairText = post.linkFlairText, !linkFlairText.isEmpty {
                Text(linkFlairText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(flairTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(flairBackgroundColor, in: RoundedRectangle(cornerRadius: 6))
            }
            
            // Main stats and actions row
            HStack(spacing: 20) {
                // Score
                Label {
                    Text(post.scoreText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "arrow.up")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                
                // Comments
                Label {
                    Text(post.commentsText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "bubble.left")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    if post.gilded > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "seal.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            
                            if post.gilded > 1 {
                                Text("\(post.gilded)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if post.locked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    if post.archived {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var flairBackgroundColor: Color {
        if let colorHex = post.linkFlairBackgroundColor, !colorHex.isEmpty {
            return Color(hex: colorHex) ?? Color.accentColor.opacity(0.2)
        }
        return Color.accentColor.opacity(0.2)
    }
    
    private var flairTextColor: Color {
        if let colorHex = post.linkFlairTextColor, colorHex == "dark" {
            return .primary
        } else if let colorHex = post.linkFlairTextColor, colorHex == "light" {
            return .white
        }
        return .primary
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

