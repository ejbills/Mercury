import Foundation

struct Subreddit: Codable, Identifiable {
    let id: String
    let displayName: String
    let displayNamePrefixed: String
    let title: String
    let description: String
    let subscribers: Int
    let iconImg: String?
    let communityIcon: String?
    let primaryColor: String?
    let isNsfw: Bool
    let publicDescription: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case displayNamePrefixed
        case title
        case description
        case subscribers
        case iconImg
        case communityIcon
        case primaryColor
        case isNsfw = "over18"  // Only this one needs manual mapping since it's not snake_case
        case publicDescription
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        displayNamePrefixed = try container.decode(String.self, forKey: .displayNamePrefixed)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        subscribers = try container.decodeIfPresent(Int.self, forKey: .subscribers) ?? 0
        iconImg = try container.decodeIfPresent(String.self, forKey: .iconImg)
        communityIcon = try container.decodeIfPresent(String.self, forKey: .communityIcon)
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor)
        isNsfw = try container.decodeIfPresent(Bool.self, forKey: .isNsfw) ?? false
        publicDescription = try container.decodeIfPresent(String.self, forKey: .publicDescription) ?? ""
    }
    
    var iconURL: URL? {
        if let communityIcon = communityIcon, !communityIcon.isEmpty {
            return URL(string: communityIcon.replacingOccurrences(of: "&amp;", with: "&"))
        } else if let iconImg = iconImg, !iconImg.isEmpty {
            return URL(string: iconImg.replacingOccurrences(of: "&amp;", with: "&"))
        }
        return nil
    }
    
    var memberCountText: String {
        if subscribers >= 1_000_000 {
            return String(format: "%.1fM", Double(subscribers) / 1_000_000.0)
        } else if subscribers >= 1_000 {
            return String(format: "%.1fK", Double(subscribers) / 1_000.0)
        } else {
            return "\(subscribers)"
        }
    }
}

struct SubredditResponse: Codable {
    let data: SubredditListData
}

struct SubredditListData: Codable {
    let children: [SubredditChild]
    let after: String?
    let before: String?
}

struct SubredditChild: Codable {
    let data: Subreddit
}

enum QuickLink: String, CaseIterable {
    case home = "Home"
    case popular = "Popular"
    case all = "All"
    case saved = "Saved"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .popular: return "chart.line.uptrend.xyaxis"
        case .all: return "globe"
        case .saved: return "bookmark.fill"
        }
    }
    
    var endpoint: String {
        switch self {
        case .home: return ""
        case .popular: return "r/popular"
        case .all: return "r/all"
        case .saved: return "user/saved"
        }
    }
}