import SwiftUI

struct LinkItemView: View {
    let link: String

    @Environment(\.navigationPathManager) private var navigationPath
    
    private var url: URL? {
        URL(string: link)
    }
    
    private var isValidUrl: Bool {
        url != nil
    }
    
    private var isRedditSubreddit: Bool {
        // Match pure subreddit links like "r/SwiftUI" or "/r/SwiftUI"
        let purePattern = #"^/?r/[a-zA-Z0-9_]+$"#
        if link.matches(purePattern) {
            return true
        }
        
        // Match full Reddit subreddit URLs like "https://www.reddit.com/r/SwiftUI/" with optional query params
        let fullPattern = #"https?://(www\.)?reddit\.com/r/[a-zA-Z0-9_]+(/?\?.*)?/?$"#
        return link.matches(fullPattern)
    }
    
    private var isRedditUser: Bool {
        // Match pure user links like "u/username" or "/u/username" 
        let purePattern = #"^/?u/[a-zA-Z0-9_-]+$"#
        if link.matches(purePattern) {
            return true
        }
        
        // Match full Reddit user URLs like "https://www.reddit.com/u/username/" with optional query params
        let fullPattern = #"https?://(www\.)?reddit\.com/u(ser)?/[a-zA-Z0-9_-]+(/?\?.*)?/?$"#
        return link.matches(fullPattern)
    }
    
    private var isRedditPost: Bool {
        // Match Reddit post URLs like reddit.com/r/subreddit/comments/id/title or redd.it/shortcode or reddit.com/r/subreddit/s/sharecode
        let redditPostPattern = #"(reddit\.com/r/[^/]+/(comments/[^/]+|s/[a-zA-Z0-9]+)|redd\.it/[a-zA-Z0-9]+)"#
        return link.matches(redditPostPattern)
    }
    
    var body: some View {
        Group {
            if isRedditSubreddit {
                redditSubredditView
            } else if isRedditUser {
                redditUserView
            } else if isRedditPost {
                redditPostView
            } else if isValidUrl {
                articleCardView
            } else {
                invalidURLView
            }
        }
    }
    
    private var articleCardView: some View {
        CompactArticleCard(
            url: link,
            fallbackThumbnail: nil,
            fallbackDomain: url?.host,
            fallbackTitle: nil,
            onTap: {
                if let url = url {
                    UIApplication.shared.open(url)
                }
            }
        )
    }
    
    private var invalidURLView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            
            Text("Invalid URL")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var redditSubredditView: some View {
        Button(action: {
            let subredditName = extractRedditName(from: link, prefix: "r/")
            navigationPath.navigate(to: .subredditFeed(subreddit: subredditName))
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.fill.secondary)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("r/\(extractRedditName(from: link, prefix: "r/"))")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("Reddit Community")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .imageScale(.small)
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.separator.opacity(0.3), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: false)
    }
    
    private var redditUserView: some View {
        Button(action: {
            let username = extractRedditName(from: link, prefix: "u/")
            navigationPath.navigate(to: .userProfile(username: username))
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.fill.secondary)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("u/\(extractRedditName(from: link, prefix: "u/"))")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("Reddit User")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .imageScale(.small)
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.separator.opacity(0.3), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: false)
    }
    
    private var redditPostView: some View {
        CompactRedditPostCard(url: link) { post in
            if let post = post {
                navigationPath.navigate(to: .postComments(post: post))
            } else {
                // Fallback: try to resolve, and navigate internally for crossposts/relative links
                Task {
                    if let fetched = await RedditPostFetchService.shared.fetchPost(from: URLNormalizer.normalizeRedditURL(link)) {
                        await MainActor.run { navigationPath.navigate(to: .postComments(post: fetched)) }
                    } else {
                        // Try resolving again with normalized URL
                        let normalized = URLNormalizer.normalizeRedditURL(link)
                        if let _ = URL(string: normalized) {
                            if let fetched2 = await RedditPostFetchService.shared.fetchPost(from: normalized) {
                                await MainActor.run { navigationPath.navigate(to: .postComments(post: fetched2)) }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func extractRedditName(from text: String, prefix: String) -> String {
        // Handle pure format like "r/SwiftUI" or "/r/SwiftUI"
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        } else if let range = text.range(of: "/\(prefix)") {
            let afterPrefix = text[range.upperBound...]
            if let spaceRange = afterPrefix.range(of: " ") {
                return String(afterPrefix[..<spaceRange.lowerBound])
            } else {
                return String(afterPrefix)
            }
        }
        
        // Handle full Reddit URLs like "https://www.reddit.com/r/SwiftUI/" with query params
        if text.contains("reddit.com/\(prefix)") {
            if let range = text.range(of: "reddit.com/\(prefix)") {
                let afterPrefix = text[range.upperBound...]
                // Find the end of the name - either "/", "?" or end of string
                let nameEnd = afterPrefix.firstIndex(where: { $0 == "/" || $0 == "?" }) ?? afterPrefix.endIndex
                return String(afterPrefix[..<nameEnd])
            }
        }
        
        return text
    }
    
}


#Preview {
    ScrollView {
        VStack(spacing: 12) {
            LinkItemView(link: "https://www.apple.com")
            LinkItemView(link: "https://github.com")
            LinkItemView(link: "https://www.reddit.com")
            LinkItemView(link: "invalid-url")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    .background(Color(UIColor.systemGroupedBackground))
}
