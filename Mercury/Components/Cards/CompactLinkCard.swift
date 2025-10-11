//
//  CompactLinkCard.swift
//  Mercury
//
//  A compact shared embed card for inline link previews in posts and comments
//

import SwiftUI
import Nuke
import NukeUI

struct CompactLinkCardMetrics {
    static let cornerRadius: CGFloat = 10
    static let thumbnailWidth: CGFloat = 70
    static let minHeight: CGFloat = 64
    static let contentPadding: CGFloat = 10
    static let contentSpacing: CGFloat = 3
}

struct CompactLinkCard<Thumbnail: View>: View {
    let thumbnail: Thumbnail
    let labelIcon: String
    let labelText: String
    let labelTint: Color
    let title: String
    let subtitle: String?
    let onTap: () -> Void

    init(
        thumbnail: Thumbnail,
        labelIcon: String,
        labelText: String,
        labelTint: Color = .secondary,
        title: String,
        subtitle: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.thumbnail = thumbnail
        self.labelIcon = labelIcon
        self.labelText = labelText
        self.labelTint = labelTint
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: CompactLinkCardMetrics.contentSpacing) {
                HStack(spacing: 3) {
                    Image(systemName: labelIcon)
                        .font(.caption2)
                        .foregroundStyle(labelTint)
                    Text(labelText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(labelTint)
                        .lineLimit(1)
                }

                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CompactLinkCardMetrics.contentPadding)

            thumbnail
                .frame(width: CompactLinkCardMetrics.thumbnailWidth)
                .frame(maxHeight: .infinity)
                .clipped()
        }
        .frame(minHeight: CompactLinkCardMetrics.minHeight)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CompactLinkCardMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CompactLinkCardMetrics.cornerRadius, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Compact Article Card

struct CompactArticleCard: View {
    let url: String
    let fallbackThumbnail: String?
    let fallbackDomain: String?
    let fallbackTitle: String?
    let onTap: () -> Void

    @State private var metadata: ArticleMetadata?

    var body: some View {
        CompactLinkCard(
            thumbnail: thumbnailView,
            labelIcon: "link",
            labelText: displayDomain,
            title: displayTitle,
            subtitle: displayDescription,
            onTap: onTap
        )
        .frame(height: CompactLinkCardMetrics.minHeight) // Fixed height prevents layout shift
        .task { await loadMetadata() }
    }

    private var thumbnailView: some View {
        Group {
            if let imageURL = metadata?.imageURL ?? fallbackThumbnail {
                LazyImage(url: URL(string: imageURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderView
                    }
                }
                .processors([.resize(size: CGSize(width: 140, height: 140))])
                .priority(.low)
                .transition(.opacity)
            } else {
                placeholderView
            }
        }
    }

    private var displayDomain: String {
        // Always return a value to maintain layout stability
        if let siteName = metadata?.siteName, !siteName.isEmpty {
            return siteName
        } else if let domain = fallbackDomain, !domain.isEmpty {
            return domain
        } else {
            return extractDomain(from: url)
        }
    }

    private var displayTitle: String {
        // Always return a value to maintain layout stability
        if let title = metadata?.title, !title.isEmpty {
            return title
        } else if let fallback = fallbackTitle, !fallback.isEmpty {
            return fallback
        } else {
            return extractDomain(from: url)
        }
    }

    private var displayDescription: String? {
        metadata?.description
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.fill.secondary)
            .overlay {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }

    private func loadMetadata() async {
        Task.detached(priority: .utility) { [url] in
            let fetchedMetadata = await MetadataService.shared.fetchMetadata(for: url)

            if let fetchedMetadata = fetchedMetadata {
                await MainActor.run {
                    if self.metadata == nil {
                        self.metadata = fetchedMetadata
                    }
                }
            }
        }
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Website" }
        let host = url.host ?? "Website"
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Compact Reddit Post Card

struct CompactRedditPostCard: View {
    let url: String
    let onTap: (RedditPost?) -> Void

    @State private var redditPost: RedditPost?

    var body: some View {
        CompactLinkCard(
            thumbnail: thumbnailView,
            labelIcon: "r.circle.fill",
            labelText: displaySubreddit,
            labelTint: .orange,
            title: displayTitle,
            subtitle: displayStats,
            onTap: { onTap(redditPost) }
        )
        .frame(height: CompactLinkCardMetrics.minHeight) // Fixed height prevents layout shift
        .task { await loadRedditPost() }
    }

    private var thumbnailView: some View {
        Group {
            if let post = redditPost,
               let thumbnailURL = extractThumbnailURL(from: post) {
                LazyImage(url: URL(string: thumbnailURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderView
                    }
                }
                .processors([.resize(size: CGSize(width: 140, height: 140))])
                .priority(.low)
                .transition(.opacity)
            } else {
                placeholderView
            }
        }
    }

    private var displayTitle: String {
        // Always return a value to maintain layout stability
        if let title = redditPost?.title, !title.isEmpty {
            return title
        }
        return "Reddit Post"
    }

    private var displaySubreddit: String {
        // Always return a value to maintain layout stability
        if let subreddit = redditPost?.subreddit, !subreddit.isEmpty {
            return "r/\(subreddit)"
        }
        if url.contains("/r/") {
            let components = url.components(separatedBy: "/r/")
            if components.count > 1 {
                let subredditPart = components[1].components(separatedBy: "/").first ?? ""
                if !subredditPart.isEmpty {
                    return "r/\(subredditPart)"
                }
            }
        }
        return "Reddit"
    }

    private var displayStats: String? {
        guard let post = redditPost else { return nil }
        let score = formatNumber(post.score)
        let comments = formatNumber(post.numComments)
        return "\(score) ↑ · \(comments) comments"
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.fill.secondary)
            .overlay {
                Image(systemName: "r.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }

    private func loadRedditPost() async {
        Task.detached(priority: .utility) { [url] in
            let fetchedPost = await RedditPostFetchService.shared.fetchPost(from: url)

            await MainActor.run {
                self.redditPost = fetchedPost
            }
        }
    }

    private func extractThumbnailURL(from post: RedditPost) -> String? {
        if let preview = post.preview,
           !preview.images.isEmpty,
           let firstImage = preview.images.first {
            let source = firstImage.source
            if !source.url.isEmpty {
                return source.url.replacingOccurrences(of: "&amp;", with: "&")
            }
        }

        if let thumbnail = post.thumbnail,
           !thumbnail.isEmpty,
           !thumbnail.contains("self"),
           !thumbnail.contains("default"),
           thumbnail.hasPrefix("http") {
            return thumbnail
        }

        if let postURL = post.url,
           (postURL.contains("i.redd.it") || postURL.contains("i.imgur.com")) {
            return postURL
        }

        return nil
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let thousands = Double(number) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(number)"
    }
}

// MARK: - Generic Compact Link Card

struct CompactGenericLinkCard: View {
    let url: String
    let icon: String
    let label: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        CompactLinkCard(
            thumbnail: placeholderView,
            labelIcon: icon,
            labelText: label,
            title: title,
            onTap: onTap
        )
        .frame(height: CompactLinkCardMetrics.minHeight)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.fill.secondary)
            .overlay {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }
}
