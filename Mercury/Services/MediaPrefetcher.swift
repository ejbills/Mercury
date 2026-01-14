import Foundation
import Nuke

/// App-wide media prefetching using Nuke's ImagePrefetcher.
/// - Unifies preloading for images and GIFs so content is warm in cache
///   before it appears on screen.
final class MediaPrefetcher {
    static let shared = MediaPrefetcher()

    private let prefetcher: ImagePrefetcher
    private let queue = DispatchQueue(label: "com.mercury.media-prefetch", qos: .utility)

    private init() {
        prefetcher = ImagePrefetcher(pipeline: ImagePipeline.shared)
    }

    // MARK: Posts

    /// Prefetches media for the given posts (images, gallery images, thumbnails, and .gif URLs).
    /// Limits the number to avoid overwhelming the network.
    func prefetch(posts: [RedditPost], limit: Int = 40) {
        queue.async {
            var requests: [ImageRequest] = []

            for post in posts.prefix(limit) {
                switch post.postType {
                case .image:
                    if let url = post.imageURL, let u = URL(string: url) {
                        requests.append(ImageRequest(url: u))
                    }
                case .gif:
                    if let url = post.gifURL, let u = URL(string: url) {
                        // Only prefetch if looks like a GIF (so Nuke can cache original bytes)
                        if url.lowercased().contains(".gif") || url.lowercased().contains("giphy") {
                            requests.append(ImageRequest(url: u))
                        }
                    }
                case .gallery:
                    for item in post.galleryImages {
                        if let u = URL(string: item.url) { requests.append(ImageRequest(url: u)) }
                    }
                case .video:
                    if let thumb = post.videoThumbnailURL, let u = URL(string: thumb) {
                        requests.append(ImageRequest(url: u))
                    }
                case .link:
                    if let thumb = post.thumbnail, let u = URL(string: thumb), self.isValidThumbnail(thumb) {
                        requests.append(ImageRequest(url: u))
                    }
                case .externalVideo:
                    if let thumb = post.externalVideoThumbnailURL, let u = URL(string: thumb) {
                        requests.append(ImageRequest(url: u))
                    }
                default:
                    break
                }
            }

            if !requests.isEmpty {
                self.prefetcher.startPrefetching(with: requests)
            }
        }
    }

    // MARK: Comments

    /// Prefetches images and GIFs found in the comment bodies.
    func prefetch(comments: [RedditComment], limit: Int = 120) {
        queue.async {
            var urls: [URL] = []
            for body in comments.prefix(limit).map({ $0.body }) {
                urls.append(contentsOf: Self.extractMediaURLs(from: body))
            }
            guard !urls.isEmpty else { return }
            let requests = urls.map { ImageRequest(url: $0) }
            self.prefetcher.startPrefetching(with: requests)
        }
    }

    // MARK: Helpers

    private func isValidThumbnail(_ url: String) -> Bool {
        guard !url.isEmpty else { return false }
        let invalid = ["self", "default", "nsfw", "spoiler"]
        return !invalid.contains(url)
    }

    private static func extractMediaURLs(from text: String) -> [URL] {
        var results: [URL] = []
        let pattern = #"https?://[^\s)\]>]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            let urlStr = ns.substring(with: match.range)
            if isImageURL(urlStr) || isGifURL(urlStr), let u = URL(string: normalize(urlStr)) {
                results.append(u)
            }
        }
        return results
    }

    private static func normalize(_ url: String) -> String {
        // Map preview.redd.it -> i.redd.it and drop query params to improve cache hits
        var str = url
        if str.contains("preview.redd.it") {
            str = str.replacingOccurrences(of: "preview.redd.it", with: "i.redd.it")
            if var comps = URLComponents(string: str) { comps.query = nil; str = comps.string ?? str }
        }
        return str
    }

    private static func isImageURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        let exts = [".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"]
        if exts.contains(where: { lower.hasSuffix($0) }) { return true }
        return lower.contains("i.redd.it") ||
               lower.contains("preview.redd.it") ||
               lower.contains("external-preview.redd.it") ||
               lower.contains("i.imgur.com") ||
               (lower.contains("redd.it") && !lower.contains("/r/"))
    }

    private static func isGifURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.hasSuffix(".gif") || lower.contains("media.giphy.com")
    }
}
