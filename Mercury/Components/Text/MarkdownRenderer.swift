import SwiftUI
import MarkdownUI
import NukeUI
import Nuke
import Defaults

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
    @Default(.bodyTextScale) private var bodyScale
    
    init(content: String, compactMode: Bool = false, showEmbeddedContent: Bool = true, attachments: [String: UIImage]? = nil) {
        self.content = content
        self.compactMode = compactMode
        self.showEmbeddedContent = showEmbeddedContent
        self.attachments = attachments
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let visible = compactMode ? String("\(processedContent.prefix(150))...") : processedContent
            Markdown(visible)
                .markdownTextStyle() {
                    FontSize(16 * bodyScale)
                }
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
        
        // Known direct image hosts
        if lowercaseURL.contains("i.redd.it") ||
           lowercaseURL.contains("preview.redd.it") ||
           lowercaseURL.contains("external-preview.redd.it") ||
           lowercaseURL.contains("i.imgur.com") ||
           (lowercaseURL.contains("redd.it") && !lowercaseURL.contains("/r/")) {
            return true
        }

        // Imgur: allow bare image pages (imgur.com/<id>) but NOT albums/galleries
        if lowercaseURL.matches(#"https?://imgur\.com/[a-zA-Z0-9]+$"#) {
            return true
        }
        if lowercaseURL.matches(#"https?://imgur\.com/(a|gallery)/[a-zA-Z0-9]+"#) {
            return false
        }

        return false
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
    private let placeholderHeight: CGFloat = 220
    
    private var processedURL: String {
        var out = url

        // Convert preview.redd.it to i.redd.it and strip parameters/fragments
        if out.contains("preview.redd.it") {
            out = out.replacingOccurrences(of: "preview.redd.it", with: "i.redd.it")
        }
        
        // Imgur conversion: only for bare image pages (not albums/galleries)
        if out.matches(#"https?://imgur\.com/[a-zA-Z0-9]+($|\?.*|#.*)"#) &&
           !out.matches(#"https?://imgur\.com/(a|gallery)/[a-zA-Z0-9]+"#) {
            if let comps = URLComponents(string: out) {
                var id = comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let slash = id.firstIndex(of: "/") { id = String(id[..<slash]) }
                if !id.isEmpty {
                    out = "https://i.imgur.com/\(id).jpg"
                }
            }
        }

        // Strip any fragments/queries for image hosts that dislike them
        if var comps = URLComponents(string: out) {
            comps.query = nil
            comps.fragment = nil
            out = comps.string ?? out
        }

        return out
    }
    
    private var isGif: Bool {
        processedURL.lowercased().hasSuffix(".gif") || processedURL.contains("media.giphy.com")
    }
    
    var body: some View {
        Group {
            if isGif, let gifURL = URL(string: processedURL) {
                FLAnimatedGifView(
                    url: gifURL,
                    contentMode: .fit,
                    cornerRadius: 12,
                    fixedHeight: nil
                )
            } else {
                imageView
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var imageView: some View {
        LazyImage(url: URL(string: processedURL)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(isLoaded ? 1 : 0)
                    .onAppear {
                        if !isLoaded {
                            withAnimation(.easeOut(duration: 0.3)) { isLoaded = true }
                        }
                    }
            } else if state.error != nil {
                // Do not impose a height while loading/errors to avoid locking parent size
                Color.clear
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
                Color.clear
                    .overlay { ProgressView().scaleEffect(1.2) }
            }
        }
        .priority(.high)
        .transition(.opacity)
    }
}
