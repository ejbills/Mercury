import SwiftUI
import MarkdownUI
import NukeUI
import Nuke

extension String {
    func matches(_ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

struct MarkdownRenderer: View {
    let content: String
    let compactMode: Bool
    let showEmbeddedContent: Bool
    
    init(content: String, compactMode: Bool = false, showEmbeddedContent: Bool = true) {
        self.content = content
        self.compactMode = compactMode
        self.showEmbeddedContent = showEmbeddedContent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Markdown(compactMode ? String("\(processedContent.prefix(150))...") : processedContent)
                .font(.system(size: 10))
                .textSelection(.enabled)
            if showEmbeddedContent {
                let embedContent = extractLinks(from: content)
                ForEach(Array(embedContent.enumerated()), id: \.offset) { index, embed in
                    switch embed {
                    case .link(let url):
                        if isImageURL(url) || isGifURL(url) {
                            EmbeddedMediaView(url: url)
                        } else {
                            LinkItemView(link: url)
                        }
                    case .giphy(let giphyFormat):
                        GiphyEmbedView(redditFormat: giphyFormat)
                    }
                }
            }
        }
    }
    
    private func extractLinks(from text: String) -> [EmbedContent] {
        var content: [EmbedContent] = []
        var processedText = text
        let giphyPattern = #"giphy(%7C|[|])[0-9A-Za-z]+(?:(%7C|[|])[a-zA-Z0-9_]+)?"#
        if let giphyRegex = try? NSRegularExpression(pattern: giphyPattern, options: []) {
            let range = NSRange(location: 0, length: processedText.utf16.count)
            let giphyMatches = giphyRegex.matches(in: processedText, options: [], range: range)
            for match in giphyMatches.reversed() {
                if let range = Range(match.range, in: processedText) {
                    let giphyString = String(processedText[range])
                    content.append(.giphy(giphyString))
                    processedText.removeSubrange(range)
                }
            }
        }
        let redditMentionPattern = #"(?<=^|\s)(u|r)/[a-zA-Z0-9_-]+(?=\s|$)"#
        if let mentionRegex = try? NSRegularExpression(pattern: redditMentionPattern, options: []) {
            let range = NSRange(location: 0, length: processedText.utf16.count)
            let mentionMatches = mentionRegex.matches(in: processedText, options: [], range: range)
            for match in mentionMatches {
                if let range = Range(match.range, in: processedText) {
                    let mentionString = String(processedText[range])
                    content.append(.link(mentionString))
                }
            }
        }
        let urlPattern = #"https?://[^\s)\]>]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let range = NSRange(location: 0, length: processedText.utf16.count)
            let matches = regex.matches(in: processedText, options: [], range: range)
            var seenURLs = Set<String>()
            let regularLinks: [EmbedContent] = matches.compactMap { match in
                if let range = Range(match.range, in: processedText) {
                    let linkURL = String(processedText[range])
                    guard !seenURLs.contains(linkURL) else { return nil }
                    seenURLs.insert(linkURL)
                    return EmbedContent.link(linkURL)
                }
                return nil
            }
            content.append(contentsOf: regularLinks)
        }
        return content
    }
    
    private var processedContent: String {
        var processed = content
        
        let giphyPattern = #"!\[gif\]\(giphy[|%][0-9A-Za-z]+(?:[|%][a-zA-Z0-9_]+)?\)"#
        processed = processed.replacingOccurrences(
            of: giphyPattern,
            with: "",
            options: .regularExpression
        )
        let standaloneGiphyPattern = #"giphy[|%][0-9A-Za-z]+(?:[|%][a-zA-Z0-9_]+)?"#
        processed = processed.replacingOccurrences(
            of: standaloneGiphyPattern,
            with: "",
            options: .regularExpression
        )
        processed = processed.replacingOccurrences(of: "&#x200B;", with: "")
        processed = processed.replacingOccurrences(of: "&amp;", with: "&")
        processed = processed.replacingOccurrences(of: "&lt;", with: "<")
        processed = processed.replacingOccurrences(of: "&gt;", with: ">")
        processed = processed.replacingOccurrences(of: "&quot;", with: "\"")
        do {
            let superscriptRegex = try NSRegularExpression(pattern: "\\^(\\w+)", options: [])
            let range = NSRange(location: 0, length: processed.utf16.count)
            processed = superscriptRegex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: range,
                withTemplate: "<sup>$1</sup>"
            )
        } catch {
            
        }
        do {
            let spoilerRegex = try NSRegularExpression(pattern: ">!([^!]+)!<", options: [])
            let range = NSRange(location: 0, length: processed.utf16.count)
            processed = spoilerRegex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: range,
                withTemplate: "[SPOILER: $1]"
            )
        } catch {
            
        }
        
        return processed
    }
    
    private func isImageURL(_ url: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "bmp", "tiff"]
        let lowercaseURL = url.lowercased()
        
        // Check for explicit image extensions
        if imageExtensions.contains(where: { lowercaseURL.hasSuffix(".\($0)") }) {
            return true
        }
        
        // Check for known image hosting domains
        return lowercaseURL.contains("i.redd.it") ||
               lowercaseURL.contains("preview.redd.it") ||
               lowercaseURL.contains("external-preview.redd.it") ||
               lowercaseURL.contains("i.imgur.com") ||
               (lowercaseURL.contains("media.giphy.com") && lowercaseURL.contains(".gif")) ||
               // Reddit images often don't have extensions but are on image domains
               (lowercaseURL.contains("redd.it") && !lowercaseURL.contains("/r/")) ||
               // Imgur images without extensions
               lowercaseURL.matches(#"https?://imgur\.com/[a-zA-Z0-9]+"#) ||
               // Imgur galleries/albums
               lowercaseURL.matches(#"https?://imgur\.com/(a|gallery)/[a-zA-Z0-9]+"#)
    }
    
    private func isGifURL(_ url: String) -> Bool {
        return url.lowercased().hasSuffix(".gif") ||
               url.contains("media.giphy.com")
    }
}

// MARK: - Embed Content Types
enum EmbedContent: Hashable {
    case link(String)
    case giphy(String)
}

// MARK: - Giphy Embed View
struct GiphyEmbedView: View {
    let redditFormat: String
    @State private var giphyMedia: GiphyMedia?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var targetHeight: CGFloat? = nil
    private let defaultHeight: CGFloat = 300
    
    var body: some View {
        VStack(spacing: 0) {
            // Stable container height derived from API dimensions when available
            Group {
                if let giphyMedia = giphyMedia, let url = URL(string: giphyMedia.url) {
                    AnimatedGifCard(
                        url: url,
                        cornerRadius: 12,
                        apiDimensions: nil,
                        maxHeight: targetHeight ?? defaultHeight,
                        fixedHeight: targetHeight ?? defaultHeight
                    )
                    .frame(maxWidth: .infinity)
                } else if hasError {
                    errorView
                } else {
                    loadingView
                }
            }
            .frame(height: targetHeight ?? defaultHeight)
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Text("Powered by GIPHY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .task {
            await loadGiphyMedia()
        }
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.3))
            .overlay {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading GIF...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var errorView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.3))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text("Failed to load GIF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private func loadGiphyMedia() async {
        guard let media = await GiphyService.resolveGiphyMedia(from: redditFormat) else {
            hasError = true
            isLoading = false
            return
        }
        
        await MainActor.run {
            self.giphyMedia = media
            self.isLoading = false
            self.targetHeight = MediaLayout.height(for: media.dimensions, maxHeight: 400, fallback: 300, minHeight: 120)
        }
    }
}

// MARK: - Embedded Media View
struct EmbeddedMediaView: View {
    let url: String
    @State private var isLoaded = false
    
    private var processedURL: String {
        var processedURL = url
        
        // Convert preview.redd.it to i.redd.it and strip parameters
        if processedURL.contains("preview.redd.it") {
            processedURL = processedURL.replacingOccurrences(of: "preview.redd.it", with: "i.redd.it")
            
            // Strip URL parameters (everything after ?)
            if let urlComponents = URLComponents(string: processedURL) {
                var components = urlComponents
                components.query = nil
                processedURL = components.string ?? processedURL
            }
        }
        
        // Convert Imgur gallery/album URLs to direct image URLs
        if processedURL.matches(#"https?://imgur\.com/(a|gallery)/[a-zA-Z0-9]+"#) {
            // Extract the ID and convert to direct image URL
            if let range = processedURL.range(of: #"/(a|gallery)/"#, options: .regularExpression) {
                let afterSlash = processedURL[range.upperBound...]
                let imageId = String(afterSlash).components(separatedBy: "/").first ?? ""
                if !imageId.isEmpty {
                    // Try the most common image format first
                    processedURL = "https://i.imgur.com/\(imageId).jpg"
                }
            }
        }
        
        return processedURL
    }
    
    private var isGif: Bool {
        processedURL.lowercased().hasSuffix(".gif") || processedURL.contains("media.giphy.com")
    }
    
    var body: some View {
        Group {
            if isGif, let gifURL = URL(string: processedURL) {
                AnimatedGifCard(url: gifURL, cornerRadius: 12, apiDimensions: nil, maxHeight: 400)
                    .frame(maxWidth: .infinity)
            } else {
                imageView
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var imageView: some View {
        LazyImage(url: URL(string: processedURL)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(isLoaded ? 1 : 0)
                    .onAppear {
                        if !isLoaded {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isLoaded = true
                            }
                        }
                    }
            } else if state.error != nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
            }
        }
        .processors([.resize(size: CGSize(width: 800, height: 600))])
        .priority(.high)
        .transition(.opacity)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownRenderer(
                content: """
                # Heading 1
                ## Heading 2
                
                This is **bold** and *italic* text.
                
                Check out r/SwiftUI and u/developer for more info.
                
                Here's an image: https://i.imgur.com/example.jpg
                
                And a [link](https://reddit.com).
                """,
                compactMode: false,
                showEmbeddedContent: true
            )
            .padding()
            
            Divider()
            
            MarkdownRenderer(
                content: "Compact mode with **formatting** and `code`.",
                compactMode: true,
                showEmbeddedContent: true
            )
            .padding()
        }
    }
}
