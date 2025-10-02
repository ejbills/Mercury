import Foundation
import Defaults
import SwiftUI

extension Defaults.Keys {
    static let clientId = Key<String>("clientId", default: "")
    static let accessToken = Key<String?>("accessToken")
    static let refreshToken = Key<String?>("refreshToken")
    static let accessTokenExpiry = Key<Date?>("accessTokenExpiry")
    static let userInfo = Key<RedditUser?>("userInfo")
    static let isSetupComplete = Key<Bool>("isSetupComplete", default: false)
    static let lastLoginDate = Key<Date?>("lastLoginDate")
    static let compactMode = Key<Bool>("compactMode", default: false)
    
    static let blockedKeywords = Key<Set<String>>("blockedKeywords", default: Set())
    static let blockedUsers = Key<Set<String>>("blockedUsers", default: Set())
    static let blockedSubreddits = Key<Set<String>>("blockedSubreddits", default: Set())
    static let keywordFilterEnabled = Key<Bool>("keywordFilterEnabled", default: true)
    static let userBlockingEnabled = Key<Bool>("userBlockingEnabled", default: true)
    static let subredditBlockingEnabled = Key<Bool>("subredditBlockingEnabled", default: true)
    
    static let blurNSFWContent = Key<Bool>("blurNSFWContent", default: true)
    // Global toggle for enabling/disabling swipe actions across the app
    static let swipeActionsEnabled = Key<Bool>("swipeActionsEnabled", default: true)
    
    static let postLeftShortSwipeAction = Key<SwipeActionType>("postLeftShortSwipeAction", default: SwipeActionType.upvote)
    static let postLeftLongSwipeAction = Key<SwipeActionType>("postLeftLongSwipeAction", default: SwipeActionType.save)
    static let postRightShortSwipeAction = Key<SwipeActionType>("postRightShortSwipeAction", default: SwipeActionType.downvote)
    static let postRightLongSwipeAction = Key<SwipeActionType>("postRightLongSwipeAction", default: SwipeActionType.share)
    static let commentLeftShortSwipeAction = Key<SwipeActionType>("commentLeftShortSwipeAction", default: SwipeActionType.upvote)
    static let commentLeftLongSwipeAction = Key<SwipeActionType>("commentLeftLongSwipeAction", default: SwipeActionType.save)
    static let commentRightShortSwipeAction = Key<SwipeActionType>("commentRightShortSwipeAction", default: SwipeActionType.downvote)
    static let commentRightLongSwipeAction = Key<SwipeActionType>("commentRightLongSwipeAction", default: SwipeActionType.reply)
    static let hiddenPostIds = Key<Set<String>>("hiddenPostIds", default: [])
    static let favoriteSubreddits = Key<Set<String>>("favoriteSubreddits", default: Set())

    // Cached data
    static let cachedSubscribedSubredditsData = Key<Data?>("cachedSubscribedSubredditsData")
    static let cachedSubscribedSubredditsDate = Key<Date?>("cachedSubscribedSubredditsDate")
    // Multireddit cache (per user)
    static let cachedUserMultiredditsData = Key<Data?>("cachedUserMultiredditsData")
    static let cachedUserMultiredditsDate = Key<Date?>("cachedUserMultiredditsDate")
    static let cachedUserMultiredditsUsername = Key<String?>("cachedUserMultiredditsUsername")

    // Proxy / Network
    static let proxyEnabled = Key<Bool>("proxyEnabled", default: false)
    static let proxyType = Key<ProxyType>("proxyType", default: .http)
    static let proxyHost = Key<String?>("proxyHost", default: nil)
    static let proxyPort = Key<Int?>("proxyPort", default: nil)
    static let proxyUsername = Key<String?>("proxyUsername", default: nil)
    static let proxyPassword = Key<String?>("proxyPassword", default: nil)
}

enum SwipeActionType: String, CaseIterable, Codable, Defaults.Serializable {
    case upvote = "upvote"
    case downvote = "downvote"
    case save = "save"
    case share = "share"
    case reply = "reply"
    case profile = "profile" // Author profile
    case subreddit = "subreddit"
    case hide = "hide"
    case hideAbove = "hideAbove"
    // Comment-specific utilities
    case collapse = "collapse"
    case collapseToTop = "collapseToTop"
    case parentComment = "parentComment"
    case copyLink = "copyLink"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .upvote: return "Upvote"
        case .downvote: return "Downvote"
        case .save: return "Save/Unsave"
        case .share: return "Share"
        case .reply: return "Reply"
        case .profile: return "Author"
        case .subreddit: return "Subreddit"
        case .hide: return "Hide"
        case .hideAbove: return "Hide Posts Above"
        case .collapse: return "Collapse"
        case .collapseToTop: return "Collapse to Top"
        case .parentComment: return "Parent Comment"
        case .copyLink: return "Copy Link"
        case .none: return "None"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .upvote: return "arrow.up"
        case .downvote: return "arrow.down"
        case .save: return "bookmark"
        case .share: return "square.and.arrow.up"
        case .reply: return "arrowshape.turn.up.left"
        case .profile: return "person.circle"
        case .subreddit: return "rectangle.grid.2x2"
        case .hide: return "eye.slash"
        case .hideAbove: return "arrow.up.doc"
        case .collapse: return "rectangle.compress.vertical"
        case .collapseToTop: return "arrow.up.to.line"
        case .parentComment: return "arrow.uturn.up"
        case .copyLink: return "link"
        case .none: return "slash.circle"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .upvote: return .orange
        case .downvote: return .blue
        case .save: return .green
        case .share: return .indigo
        case .reply: return .purple
        case .profile: return .mint
        case .subreddit: return .teal
        case .hide: return .gray
        case .hideAbove: return .brown
        case .collapse: return .cyan
        case .collapseToTop: return .cyan
        case .parentComment: return .pink
        case .copyLink: return .cyan
        case .none: return .gray
        }
    }
    
    var availableForPosts: Bool {
        switch self {
        case .collapse, .collapseToTop, .parentComment: return false
        default: return true
        }
    }
    
    var availableForComments: Bool {
        switch self {
        case .subreddit, .hide, .hideAbove: return false
        default: return true
        }
    }
}

enum ProxyType: String, CaseIterable, Codable, Defaults.Serializable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"

    var displayName: String { rawValue }
}
