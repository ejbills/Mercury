import Foundation

struct MultiReddit: Codable, Identifiable {
    // Reddit returns objects with kind=LabeledMulti and data={...}
    // We only keep the essentials we need for listing and navigation.
    let name: String
    let path: String // e.g. "/user/<username>/m/<multi>"
    let descriptionMd: String?
    let iconUrl: String?
    let subreddits: [String]

    var id: String { path }

    var displayName: String { name }
    var iconURL: URL? {
        guard let iconUrl = iconUrl, !iconUrl.isEmpty else { return nil }
        return URL(string: iconUrl.replacingOccurrences(of: "&amp;", with: "&"))
    }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case descriptionMd
        case iconUrl
        case subreddits
    }

    // The API returns subreddits as an array of objects with a `name` field.
    struct NamedSubreddit: Codable { let name: String }
}

struct LabeledMulti: Codable {
    let data: MultiData

    struct MultiData: Codable {
        let name: String
        let path: String
        let descriptionMd: String?
        let iconUrl: String?
        let subreddits: [MultiReddit.NamedSubreddit]
    }
}

