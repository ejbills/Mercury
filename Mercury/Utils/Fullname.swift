import Foundation

/// Utility for working with Reddit thing fullnames.
/// Ensures callers don't hand-roll prefixes (t1_, t3_, etc.).
enum Fullname {
    /// Normalize an id or fullname into a clean (prefix?, id) tuple.
    static func normalize(_ idOrFullname: String) -> (prefix: String?, id: String) {
        if let underscore = idOrFullname.firstIndex(of: "_"), underscore > idOrFullname.startIndex {
            let prefix = String(idOrFullname[..<underscore])
            let id = String(idOrFullname[idOrFullname.index(after: underscore)...])
            if prefix.hasPrefix("t"), !id.isEmpty { return (prefix, id) }
        }
        return (nil, idOrFullname)
    }

    /// Build a fullname from an id or fullname, forcing the given prefix.
    private static func build(_ typePrefix: String, from idOrFullname: String) -> String {
        let norm = normalize(idOrFullname)
        if norm.prefix == typePrefix { return idOrFullname }
        return "\(typePrefix)_\(norm.id)"
    }

    /// Ensure a t1_ fullname (comment).
    static func comment(_ idOrFullname: String) -> String { build("t1", from: idOrFullname) }
    /// Ensure a t3_ fullname (link/post).
    static func post(_ idOrFullname: String) -> String { build("t3", from: idOrFullname) }
    /// Ensure a t4_ fullname (message).
    static func message(_ idOrFullname: String) -> String { build("t4", from: idOrFullname) }
    /// Ensure a t5_ fullname (subreddit).
    static func subreddit(_ idOrFullname: String) -> String { build("t5", from: idOrFullname) }
    /// Ensure a t2_ fullname (account).
    static func account(_ idOrFullname: String) -> String { build("t2", from: idOrFullname) }
    /// Ensure a t6_ fullname (award).
    static func award(_ idOrFullname: String) -> String { build("t6", from: idOrFullname) }
}

