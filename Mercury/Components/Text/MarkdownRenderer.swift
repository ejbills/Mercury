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
    let attachments: [String: UIImage]?
    
    init(content: String, compactMode: Bool = false, showEmbeddedContent: Bool = true, attachments: [String: UIImage]? = nil) {
        self.content = content
        self.compactMode = compactMode
        self.showEmbeddedContent = showEmbeddedContent
        self.attachments = attachments
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Markdown(compactMode ? String("\(processedContent.prefix(150))...") : processedContent)
                .appFont(.body)
                .textSelection(.enabled)
            if showEmbeddedContent {
                let embedContent = extractLinks(from: content)
                ForEach(Array(embedContent.enumerated()), id: \.offset) { index, embed in
                    switch embed {
                    case .link(let url):
                        if isImageURL(url) || isGifURL(url) || isGiphyLink(url) {
                            if isGiphyLink(url) {
                                EmbeddedGiphyView(source: url)
                            } else {
                                EmbeddedMediaView(url: url)
                            }
                        } else {
                            LinkItemView(link: url)
                        }
                    case .giphyToken(let token):
                        EmbeddedGiphyView(source: token)
                    case .attachment(let key):
                        if let image = attachments?[key] {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
    
    private func extractLinks(from text: String) -> [EmbedContent] {
        var content: [EmbedContent] = []
        var processedText = text
        // Detect inline attachments in the form: ![alt](attachment://key)
        let attachmentPattern = #"!\[[^\]]*\]\(attachment://([a-zA-Z0-9_\-]+)\)"#
        if let attachmentRegex = try? NSRegularExpression(pattern: attachmentPattern, options: []) {
            let range = NSRange(location: 0, length: processedText.utf16.count)
            let matches = attachmentRegex.matches(in: processedText, options: [], range: range)
            for match in matches.reversed() {
                if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: processedText) {
                    let key = String(processedText[r])
                    content.append(.attachment(key))
                    if let fullRange = Range(match.range(at: 0), in: processedText) {
                        processedText.removeSubrange(fullRange)
                    }
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

        // Detect GIPHY tokens Reddit may include (e.g. giphy|ID or giphy%7CID)
        let giphyTokenPattern = #"giphy(?:\||%7C)[^\s)\]>]+"#
        if let giphyRegex = try? NSRegularExpression(pattern: giphyTokenPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: processedText.utf16.count)
            let matches = giphyRegex.matches(in: processedText, options: [], range: range)
            for m in matches {
                if let r = Range(m.range, in: processedText) {
                    let token = String(processedText[r])
                    content.append(.giphyToken(token))
                }
            }
            // Strip tokens out of the visible markdown
            processedText = giphyRegex.stringByReplacingMatches(in: processedText, options: [], range: range, withTemplate: "")
        }
        return content
    }
    
    private var processedContent: String {
        var processed = content
        
        // Strip custom attachment tokens so they don't show up in Markdown
        let attachmentPattern = #"!\[[^\]]*\]\(attachment://([a-zA-Z0-9_\-]+)\)"#
        processed = processed.replacingOccurrences(of: attachmentPattern, with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "&#x200B;", with: "")
        processed = processed.replacingOccurrences(of: "&amp;", with: "&")
        processed = processed.replacingOccurrences(of: "&lt;", with: "<")
        processed = processed.replacingOccurrences(of: "&gt;", with: ">")
        processed = processed.replacingOccurrences(of: "&quot;", with: "\"")
        // Remove any raw giphy tokens from rendered markdown
        let giphyTokenPattern = #"giphy(?:\||%7C)[^\s)\]>]+"#
        processed = processed.replacingOccurrences(of: giphyTokenPattern, with: "", options: .regularExpression)
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
               // Reddit images often don't have extensions but are on image domains
               (lowercaseURL.contains("redd.it") && !lowercaseURL.contains("/r/")) ||
               // Imgur images without extensions
               lowercaseURL.matches(#"https?://imgur\.com/[a-zA-Z0-9]+"#) ||
               // Imgur galleries/albums
               lowercaseURL.matches(#"https?://imgur\.com/(a|gallery)/[a-zA-Z0-9]+"#)
    }
    
    private func isGifURL(_ url: String) -> Bool {
        return url.lowercased().hasSuffix(".gif")
    }

    private func isGiphyLink(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("media.giphy.com") || lower.contains("giphy.com/gifs/") || lower.contains("giphy.com/stickers/")
    }
}

// MARK: - Embed Content Types
enum EmbedContent: Hashable {
    case link(String)
    case giphyToken(String)
    case attachment(String)
}

// MARK: - Embedded Media View
struct EmbeddedMediaView: View {
    let url: String
    @State private var isLoaded = false
    private let fixedHeight: CGFloat = 300
    
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
                GeometryReader { proxy in
                    FLAnimatedGifView(
                        url: gifURL,
                        contentMode: .fit,
                        cornerRadius: 12,
                        fixedHeight: fixedHeight
                    )
                    .frame(width: proxy.size.width, height: fixedHeight)
                }
                .frame(height: fixedHeight)
            } else {
                imageView
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var imageView: some View {
        LazyImage(url: URL(string: processedURL)) { state in
            if let image = state.image {
                GeometryReader { proxy in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: fixedHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isLoaded ? 1 : 0)
                        .onAppear {
                            if !isLoaded {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoaded = true
                                }
                            }
                            
                        }
                        
                }
                .frame(height: fixedHeight)
            } else if state.error != nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: fixedHeight)
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
                    .frame(height: fixedHeight)
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
