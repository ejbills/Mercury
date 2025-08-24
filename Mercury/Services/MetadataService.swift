import Foundation
import SwiftUI

extension String {
    func decodingHTMLEntities() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        var documentAttributes: NSDictionary?
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: &documentAttributes) else {
            return self
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&#x27;", with: "'")
        }
        
        return attributedString.string
    }
}

class MetadataService {
    static let shared = MetadataService()
    private let cache = NSCache<NSString, CachedMetadata>()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
        
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func fetchMetadata(for url: String) async -> ArticleMetadata? {
        let cacheKey = NSString(string: url)
        if let cached = cache.object(forKey: cacheKey) {
            return cached.metadata
        }
        
        return await fetchFromNetwork(url: url)
    }
    
    private func fetchFromNetwork(url: String) async -> ArticleMetadata? {
        guard let requestURL = URL(string: url) else { return nil }
        
        var request = URLRequest(url: requestURL)
        
        request.setValue("facebookexternalhit/1.1", forHTTPHeaderField: "User-Agent")
        request.setValue("UTF-8", forHTTPHeaderField: "charset")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("upgrade-insecure-requests", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let metadata = parseMetadata(from: html, originalURL: url)
            
            let cacheKey = NSString(string: url)
            let cachedMetadata = CachedMetadata(metadata: metadata)
            cache.setObject(cachedMetadata, forKey: cacheKey)
            
            return metadata
            
        } catch {
            return nil
        }
    }
    
    private func parseMetadata(from html: String, originalURL: String) -> ArticleMetadata {
        var title: String?
        var description: String?
        var imageURL: String?
        var siteName: String?
        
        let metaTagPattern = #"<meta\s+(?:property|name|itemprop)=["\']([^"\']+)["\']\s+content=["\']([^"\']*)["\'][^>]*>"#
        let metaRegex = try? NSRegularExpression(pattern: metaTagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        
        let htmlRange = NSRange(location: 0, length: html.count)
        metaRegex?.enumerateMatches(in: html, options: [], range: htmlRange) { match, _, _ in
            guard let match = match,
                  let propertyRange = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 2), in: html) else { return }
            
            let property = String(html[propertyRange]).lowercased()
            let content = String(html[contentRange])
            
            switch property {
            case "og:title", "twitter:title":
                if title == nil { title = content }
            case "og:description", "twitter:description", "description":
                if description == nil { description = content }
            case "og:image", "twitter:image", "twitter:image:src":
                if imageURL == nil { imageURL = content }
            case "og:site_name", "twitter:site":
                if siteName == nil { siteName = content }
            default:
                break
            }
        }
        
        if title == nil {
            let titlePattern = #"<title[^>]*>([^<]+)</title>"#
            let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive])
            if let match = titleRegex?.firstMatch(in: html, options: [], range: htmlRange),
               let titleRange = Range(match.range(at: 1), in: html) {
                title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let relativeImageURL = imageURL, !relativeImageURL.hasPrefix("http") {
            if let baseURL = URL(string: originalURL) {
                imageURL = URL(string: relativeImageURL, relativeTo: baseURL)?.absoluteString
            }
        }
        
        return ArticleMetadata(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities(),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities(),
            imageURL: imageURL,
            siteName: siteName?.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities(),
            originalURL: originalURL
        )
    }
}

private class CachedMetadata {
    let metadata: ArticleMetadata
    
    init(metadata: ArticleMetadata) {
        self.metadata = metadata
    }
}

struct ArticleMetadata {
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let originalURL: String
    
    var hasRichContent: Bool {
        return title != nil || description != nil || imageURL != nil
    }
}
