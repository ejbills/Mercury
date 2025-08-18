import SwiftUI

struct LinkItemView: View {
    let link: String
    
    @State private var metadata: ArticleMetadata?
    @State private var imageStatus: ImageStatus = .loading
    @Environment(\.colorScheme) private var colorScheme
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
    
    private var isImageDomain: Bool {
        let lowercaseLink = link.lowercased()
        return lowercaseLink.contains("i.redd.it") ||
               lowercaseLink.contains("preview.redd.it") ||
               lowercaseLink.contains("external-preview.redd.it") ||
               lowercaseLink.contains("i.imgur.com") ||
               lowercaseLink.contains("media.giphy.com") ||
               (lowercaseLink.contains("redd.it") && !lowercaseLink.contains("/r/") && !isRedditPost)
    }
    
    var body: some View {
        Group {
            if isRedditSubreddit {
                redditSubredditView
            } else if isRedditUser {
                redditUserView
            } else if isRedditPost {
                redditPostView
            } else if isValidUrl, let url {
                Link(destination: url) {
                    linkCard
                }
                .buttonStyle(LinkCardButtonStyle())
            } else {
                invalidURLView
            }
        }
        .task(id: url) {
            if !isRedditSubreddit && !isRedditUser && !isRedditPost && !isImageDomain {
                await fetchMetadata()
            }
        }
    }
    
    private var linkCard: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 4) {
                titleView
                domainView
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var thumbnailView: some View {
        Group {
            switch imageStatus {
            case .loading:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                    }
                
            case .finished(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .clipped()
                
            case .failed:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 60, height: 60)
    }
    
    private var titleView: some View {
        Text(metadata?.title ?? url?.host ?? url?.absoluteString ?? "Loading...")
            .font(.system(.subheadline, design: .default, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .redacted(reason: metadata == nil ? .placeholder : [])
            .animation(.easeInOut(duration: 0.3), value: metadata?.title)
    }
    
    private var domainView: some View {
        Group {
            if metadata != nil {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(url?.host ?? "Unknown domain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(url?.host ?? "Unknown domain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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
        RedditPostCard(url: link) {
            Task {
                if let post = await RedditPostFetchService.shared.fetchPost(from: link) {
                    await MainActor.run {
                        navigationPath.navigate(to: .postComments(post: post))
                    }
                }
            }
        }
    }
    
    private func extractPostIdFromURL(_ url: String) -> String? {
        // Extract post ID from Reddit URLs
        if url.contains("/comments/") {
            let components = url.components(separatedBy: "/comments/")
            if components.count > 1 {
                let afterComments = components[1]
                let idComponents = afterComments.components(separatedBy: "/")
                return idComponents.first
            }
        } else if url.contains("redd.it/") {
            return url.components(separatedBy: "redd.it/").last
        }
        return nil
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
    
    private var cardBackground: Color {
        colorScheme == .dark ? 
            Color(UIColor.secondarySystemGroupedBackground) : 
            Color(UIColor.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? 
            Color(UIColor.separator).opacity(0.3) : 
            Color(UIColor.separator).opacity(0.2)
    }
}

// MARK: - Button Styles
struct LinkCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AppleLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Private Methods
extension LinkItemView {
    private func fetchMetadata() async {
        guard let url = url else { return }
        
        let fetchedMetadata = await MetadataService.shared.fetchMetadata(for: url.absoluteString)
        
        await MainActor.run {
            self.metadata = fetchedMetadata
        }
        
        // Load image if available
        if let imageURL = fetchedMetadata?.imageURL {
            await loadImage(from: imageURL)
        } else {
            await MainActor.run {
                self.imageStatus = .failed
            }
        }
    }
    
    private func loadImage(from imageURL: String) async {
        guard let url = URL(string: imageURL) else {
            await MainActor.run {
                self.imageStatus = .failed
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.imageStatus = .finished(Image(uiImage: uiImage))
                }
            } else {
                await MainActor.run {
                    self.imageStatus = .failed
                }
            }
        } catch {
            await MainActor.run {
                self.imageStatus = .failed
            }
        }
    }
}

enum ImageStatus {
    case loading
    case finished(Image)
    case failed
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
