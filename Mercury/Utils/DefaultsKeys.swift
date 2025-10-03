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
    // Appearance - Posts
    static let postLayoutStyle = Key<PostLayoutStyle>("postLayoutStyle", default: .normal)
    // Normal layout options
    static let postNormalShowSubreddit = Key<Bool>("postNormalShowSubreddit", default: true)
    static let postNormalShowSubredditIcon = Key<Bool>("postNormalShowSubredditIcon", default: true)
    static let postNormalShowAuthor = Key<Bool>("postNormalShowAuthor", default: true)
    static let postNormalShowAvatar = Key<Bool>("postNormalShowAvatar", default: true)
    static let postNormalShowTime = Key<Bool>("postNormalShowTime", default: true)
    static let postNormalShowDomain = Key<Bool>("postNormalShowDomain", default: true)
    static let postNormalShowFlair = Key<Bool>("postNormalShowFlair", default: true)
    static let postNormalShowScore = Key<Bool>("postNormalShowScore", default: true)
    static let postNormalShowCommentCount = Key<Bool>("postNormalShowCommentCount", default: true)
    static let postNormalShowVoting = Key<Bool>("postNormalShowVoting", default: true)
    static let postNormalShowActions = Key<Bool>("postNormalShowActions", default: true)
    static let postNormalUseCardStyle = Key<Bool>("postNormalUseCardStyle", default: true)
    // Compact layout options
    static let postCompactThumbnailSize = Key<ThumbnailSize>("postCompactThumbnailSize", default: .medium)
    static let postCompactThumbnailPosition = Key<ThumbnailPosition>("postCompactThumbnailPosition", default: .right)
    static let postCompactShowThumbnail = Key<Bool>("postCompactShowThumbnail", default: true)
    static let postCompactHideTextThumbnails = Key<Bool>("postCompactHideTextThumbnails", default: false)
    static let postCompactShowSubreddit = Key<Bool>("postCompactShowSubreddit", default: true)
    static let postCompactShowSubredditIcon = Key<Bool>("postCompactShowSubredditIcon", default: true)
    static let postCompactShowAuthor = Key<Bool>("postCompactShowAuthor", default: true)
    static let postCompactShowAvatar = Key<Bool>("postCompactShowAvatar", default: true)
    static let postCompactShowTime = Key<Bool>("postCompactShowTime", default: true)
    static let postCompactShowDomain = Key<Bool>("postCompactShowDomain", default: true)
    static let postCompactShowFlair = Key<Bool>("postCompactShowFlair", default: true)
    static let postCompactShowScore = Key<Bool>("postCompactShowScore", default: true)
    static let postCompactShowCommentCount = Key<Bool>("postCompactShowCommentCount", default: true)
    static let postCompactShowVoting = Key<Bool>("postCompactShowVoting", default: true)
    static let postCompactShowActions = Key<Bool>("postCompactShowActions", default: true)
    static let postCompactUseCardStyle = Key<Bool>("postCompactUseCardStyle", default: true)

    // Appearance - Comments
    static let commentLayoutStyle = Key<CommentLayoutStyle>("commentLayoutStyle", default: .normal)
    // Normal comment layout options
    static let commentNormalShowAuthor = Key<Bool>("commentNormalShowAuthor", default: true)
    static let commentNormalShowAvatar = Key<Bool>("commentNormalShowAvatar", default: true)
    static let commentNormalShowTime = Key<Bool>("commentNormalShowTime", default: true)
    static let commentNormalShowScore = Key<Bool>("commentNormalShowScore", default: true)
    static let commentNormalShowVoteButtons = Key<Bool>("commentNormalShowVoteButtons", default: true)
    static let commentNormalShowActions = Key<Bool>("commentNormalShowActions", default: true)
    static let commentNormalUseCardStyle = Key<Bool>("commentNormalUseCardStyle", default: true)
    // Compact comment layout options
    static let commentCompactShowAuthor = Key<Bool>("commentCompactShowAuthor", default: true)
    static let commentCompactShowAvatar = Key<Bool>("commentCompactShowAvatar", default: true)
    static let commentCompactShowTime = Key<Bool>("commentCompactShowTime", default: true)
    static let commentCompactShowScore = Key<Bool>("commentCompactShowScore", default: true)
    static let commentCompactShowVoteButtons = Key<Bool>("commentCompactShowVoteButtons", default: true)
    static let commentCompactShowActions = Key<Bool>("commentCompactShowActions", default: true)
    static let commentCompactUseCardStyle = Key<Bool>("commentCompactUseCardStyle", default: true)

    static let blockedKeywords = Key<Set<String>>("blockedKeywords", default: Set())
    static let blockedUsers = Key<Set<String>>("blockedUsers", default: Set())
    static let blockedSubreddits = Key<Set<String>>("blockedSubreddits", default: Set())
    static let keywordFilterEnabled = Key<Bool>("keywordFilterEnabled", default: true)
    static let userBlockingEnabled = Key<Bool>("userBlockingEnabled", default: true)
    static let subredditBlockingEnabled = Key<Bool>("subredditBlockingEnabled", default: true)
    
    static let blurNSFWContent = Key<Bool>("blurNSFWContent", default: true)
    // Global toggle for enabling/disabling swipe actions across the app
    static let swipeActionsEnabled = Key<Bool>("swipeActionsEnabled", default: true)
    
    // Legacy left/right short/long (kept for migration compatibility)
    static let postLeftShortSwipeAction = Key<SwipeActionType>("postLeftShortSwipeAction", default: SwipeActionType.none)
    static let postLeftLongSwipeAction = Key<SwipeActionType>("postLeftLongSwipeAction", default: SwipeActionType.none)
    static let postRightShortSwipeAction = Key<SwipeActionType>("postRightShortSwipeAction", default: SwipeActionType.none)
    static let postRightLongSwipeAction = Key<SwipeActionType>("postRightLongSwipeAction", default: SwipeActionType.none)
    static let commentLeftShortSwipeAction = Key<SwipeActionType>("commentLeftShortSwipeAction", default: SwipeActionType.none)
    static let commentLeftLongSwipeAction = Key<SwipeActionType>("commentLeftLongSwipeAction", default: SwipeActionType.none)
    static let commentRightShortSwipeAction = Key<SwipeActionType>("commentRightShortSwipeAction", default: SwipeActionType.none)
    static let commentRightLongSwipeAction = Key<SwipeActionType>("commentRightLongSwipeAction", default: SwipeActionType.none)

    // New: Right-side only, four levels (near → far)
    static let postRightSwipeAction1 = Key<SwipeActionType>("postRightSwipeAction1", default: .upvote)
    static let postRightSwipeAction2 = Key<SwipeActionType>("postRightSwipeAction2", default: .downvote)
    static let postRightSwipeAction3 = Key<SwipeActionType>("postRightSwipeAction3", default: .save)
    static let postRightSwipeAction4 = Key<SwipeActionType>("postRightSwipeAction4", default: .share)

    static let commentRightSwipeAction1 = Key<SwipeActionType>("commentRightSwipeAction1", default: .upvote)
    static let commentRightSwipeAction2 = Key<SwipeActionType>("commentRightSwipeAction2", default: .downvote)
    static let commentRightSwipeAction3 = Key<SwipeActionType>("commentRightSwipeAction3", default: .reply)
    static let commentRightSwipeAction4 = Key<SwipeActionType>("commentRightSwipeAction4", default: .save)
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

    // Text sizing (independent of AX size)
    static let titleTextScale = Key<Double>("titleTextScale", default: 1.0)
    static let bodyTextScale = Key<Double>("bodyTextScale", default: 1.0)
    static let captionTextScale = Key<Double>("captionTextScale", default: 1.0)

    // Global appearance tuning
    static let appColorScheme = Key<AppColorSchemePreference>("appColorScheme", default: .system)
    static let feedBackgroundStyle = Key<FeedBackgroundStyle>("feedBackgroundStyle", default: .system)
    static let feedItemSpacing = Key<Double>("feedItemSpacing", default: 8.0)
    static let postHorizontalPadding = Key<Double>("postHorizontalPadding", default: 12.0)
    static let commentHorizontalPadding = Key<Double>("commentHorizontalPadding", default: 12.0)
    static let feedHorizontalPadding = Key<Double>("feedHorizontalPadding", default: 12.0) // Legacy shim
    static let customFeedBackgroundColor = Key<SerializableColor?>("customFeedBackgroundColor")
    static let commentRowVerticalPadding = Key<Double>("commentRowVerticalPadding", default: 4.0)

    static let postNormalCardCornerRadius = Key<Double>("postNormalCardCornerRadius", default: 16.0)
    static let postCompactCardCornerRadius = Key<Double>("postCompactCardCornerRadius", default: 8.0)
    static let commentRootCardCornerRadius = Key<Double>("commentRootCardCornerRadius", default: 16.0)
    static let commentChildCardCornerRadius = Key<Double>("commentChildCardCornerRadius", default: 12.0)
}

enum PostLayoutStyle: String, CaseIterable, Codable, Defaults.Serializable {
    case normal
    case compact
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .compact: return "Compact"
        }
    }
}

enum CommentLayoutStyle: String, CaseIterable, Codable, Defaults.Serializable {
    case normal
    case compact
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .compact: return "Compact"
        }
    }
}

enum ThumbnailSize: String, CaseIterable, Codable, Defaults.Serializable {
    case small
    case medium
    case large
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var dimension: CGFloat {
        switch self {
        case .small: return 48
        case .medium: return 60
        case .large: return 80
        }
    }
}

enum ThumbnailPosition: String, CaseIterable, Codable, Defaults.Serializable {
    case left
    case right

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
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

enum AppColorSchemePreference: String, CaseIterable, Codable, Defaults.Serializable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Always Light"
        case .dark: return "Always Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum FeedBackgroundStyle: String, CaseIterable, Codable, Defaults.Serializable {
    case system
    case soft
    case paper
    case midnight
    case custom

    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .soft: return "Soft Gray"
        case .paper: return "Warm Paper"
        case .midnight: return "Midnight"
        case .custom: return "Custom"
        }
    }

    func resolveColor(custom: Color?) -> Color {
        switch self {
        case .system:
            return Color(UIColor.systemBackground)
        case .soft:
            return Color(red: 0.94, green: 0.95, blue: 0.97)
        case .paper:
            return Color(red: 0.96, green: 0.94, blue: 0.88)
        case .midnight:
            return Color(red: 0.09, green: 0.10, blue: 0.14)
        case .custom:
            return custom ?? Color(UIColor.systemBackground)
        }
    }
}

enum ProxyType: String, CaseIterable, Codable, Defaults.Serializable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"

    var displayName: String { rawValue }
}
