import Foundation

enum URLNormalizer {
    /// Normalizes Reddit-style URLs that may be schemeless (//...),
    /// host-only (reddit.com/...), or relative (/r/...).
    /// Returns a string suitable for URL(string:).
    static func normalizeRedditURL(_ s: String) -> String {
        let str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("//") { return "https:" + str }
        if str.hasPrefix("/") { return "https://www.reddit.com" + str }
        let lower = str.lowercased()
        if lower.hasPrefix("reddit.com") || lower.hasPrefix("www.reddit.com") { return "https://" + str }
        return str
    }

    /// Normalizes schemeless web URLs (//example.com -> https://example.com).
    /// If the string is relative (/path), will prepend the provided host if given.
    static func normalizeWebURL(_ s: String, defaultHost: String? = nil) -> String {
        let str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("//") { return "https:" + str }
        if str.hasPrefix("/"), let host = defaultHost { return "https://\(host)" + str }
        return str
    }
}
