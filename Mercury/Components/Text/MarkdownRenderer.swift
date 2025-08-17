import SwiftUI
import MarkdownUI

struct MarkdownRenderer: View {
    let content: String
    let compactMode: Bool
    let showEmbeddedContent: Bool
    
    init(content: String, compactMode: Bool, showEmbeddedContent: Bool = true) {
        self.content = content
        self.compactMode = compactMode
        self.showEmbeddedContent = showEmbeddedContent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Markdown text
            Markdown(processedContent)
                .font(.system(size: compactMode ? 14 : 16))
                .textSelection(.enabled)
            
            // Simple link detection for LinkItemView
            if showEmbeddedContent {
                let links = extractLinks(from: content)
                ForEach(links, id: \.self) { link in
                    LinkItemView(link: link)
                }
            }
        }
    }
    
    private func extractLinks(from text: String) -> [String] {
        let urlPattern = #"https?://[^\s)\]>]+"#
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []) else { return [] }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
            return nil
        }
    }
    
    private var processedContent: String {
        var processed = content
        
        // Handle Reddit-specific markdown quirks
        // Convert Reddit's &#x200B; (zero-width space) markers
        processed = processed.replacingOccurrences(of: "&#x200B;", with: "")
        
        // Convert Reddit's &amp; entities
        processed = processed.replacingOccurrences(of: "&amp;", with: "&")
        processed = processed.replacingOccurrences(of: "&lt;", with: "<")
        processed = processed.replacingOccurrences(of: "&gt;", with: ">")
        processed = processed.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Handle Reddit's superscript format using NSRegularExpression
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
            // If regex fails, continue without superscript conversion
        }
        
        // Convert Reddit spoilers >!text!< to a visible format for now
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
            // If regex fails, continue without spoiler conversion
        }
        
        return processed
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