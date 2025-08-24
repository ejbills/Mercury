import Foundation
import CoreGraphics
import Defaults

struct RedditPost: Codable, Identifiable, Hashable {
    let id: String
    let subreddit: String
    let subredditNamePrefixed: String?
    let title: String
    let author: String
    let authorFullname: String?
    let selftext: String?
    let selftextHtml: String?
    let url: String?
    let permalink: String
    let domain: String?
    let score: Int
    let upvoteRatio: Double
    let numComments: Int
    let created: Double?
    let createdUtc: Double?
    let thumbnail: String?
    let preview: PreviewData?
    let postHint: String?
    let isVideo: Bool
    let isGallery: Bool?
    let mediaMetadata: [String: MediaMetadataItem]?
    let media: MediaData?
    let secureMedia: MediaData?
    let mediaEmbed: MediaEmbed?
    let secureMediaEmbed: MediaEmbed?
    let linkFlairText: String?
    let linkFlairBackgroundColor: String?
    let linkFlairTextColor: String?
    let authorFlairText: String?
    let isNsfw: Bool
    let isSpoiler: Bool
    let isPinned: Bool
    let isStickied: Bool
    let locked: Bool
    let archived: Bool
    let gilded: Int
    let distinguished: String?
    let edited: EditedData?
    let saved: Bool
    let hidden: Bool
    let clicked: Bool
    let visited: Bool
    let ups: Int
    let downs: Int
    let likes: Bool?
    
    var currentVoteState: VoteState = .neutral
    var displayScore: Int
    var authorIconURL: URL? = nil
    
    enum VoteState {
        case upvoted
        case downvoted
        case neutral
    }
    
    enum CodingKeys: String, CodingKey {
        case id, subreddit, title, author, selftext, url, permalink, domain, score, thumbnail, preview, media, gilded, distinguished, edited, saved, hidden, clicked, visited, ups, downs, likes, locked, archived
        case subredditNamePrefixed = "subreddit_name_prefixed"
        case selftextHtml = "selftext_html"
        case upvoteRatio = "upvote_ratio"
        case numComments = "num_comments"
        case created
        case createdUtc = "created_utc"
        case authorFullname = "author_fullname"
        case postHint = "post_hint"
        case isVideo = "is_video"
        case isGallery = "is_gallery"
        case mediaMetadata = "media_metadata"
        case secureMedia = "secure_media"
        case mediaEmbed = "media_embed"
        case secureMediaEmbed = "secure_media_embed"
        case linkFlairText = "link_flair_text"
        case linkFlairBackgroundColor = "link_flair_background_color"
        case linkFlairTextColor = "link_flair_text_color"
        case authorFlairText = "author_flair_text"
        case isNsfw = "over_18"
        case isSpoiler = "spoiler"
        case isPinned = "pinned"
        case isStickied = "stickied"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        subreddit = try container.decode(String.self, forKey: .subreddit)
        subredditNamePrefixed = try container.decodeIfPresent(String.self, forKey: .subredditNamePrefixed)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        authorFullname = try container.decodeIfPresent(String.self, forKey: .authorFullname)
        selftext = try container.decodeIfPresent(String.self, forKey: .selftext)
        selftextHtml = try container.decodeIfPresent(String.self, forKey: .selftextHtml)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        permalink = try container.decode(String.self, forKey: .permalink)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        upvoteRatio = try container.decodeIfPresent(Double.self, forKey: .upvoteRatio) ?? 0.5
        numComments = try container.decodeIfPresent(Int.self, forKey: .numComments) ?? 0
        created = try container.decodeIfPresent(Double.self, forKey: .created)
        createdUtc = try container.decodeIfPresent(Double.self, forKey: .createdUtc)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        preview = try container.decodeIfPresent(PreviewData.self, forKey: .preview)
        postHint = try container.decodeIfPresent(String.self, forKey: .postHint)
        isVideo = try container.decodeIfPresent(Bool.self, forKey: .isVideo) ?? false
        isGallery = try container.decodeIfPresent(Bool.self, forKey: .isGallery)
        mediaMetadata = try container.decodeIfPresent([String: MediaMetadataItem].self, forKey: .mediaMetadata)
        media = try container.decodeIfPresent(MediaData.self, forKey: .media)
        secureMedia = try container.decodeIfPresent(MediaData.self, forKey: .secureMedia)
        mediaEmbed = try container.decodeIfPresent(MediaEmbed.self, forKey: .mediaEmbed)
        secureMediaEmbed = try container.decodeIfPresent(MediaEmbed.self, forKey: .secureMediaEmbed)
        linkFlairText = try container.decodeIfPresent(String.self, forKey: .linkFlairText)
        linkFlairBackgroundColor = try container.decodeIfPresent(String.self, forKey: .linkFlairBackgroundColor)
        linkFlairTextColor = try container.decodeIfPresent(String.self, forKey: .linkFlairTextColor)
        authorFlairText = try container.decodeIfPresent(String.self, forKey: .authorFlairText)
        isNsfw = try container.decodeIfPresent(Bool.self, forKey: .isNsfw) ?? false
        isSpoiler = try container.decodeIfPresent(Bool.self, forKey: .isSpoiler) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isStickied = try container.decodeIfPresent(Bool.self, forKey: .isStickied) ?? false
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        gilded = try container.decodeIfPresent(Int.self, forKey: .gilded) ?? 0
        distinguished = try container.decodeIfPresent(String.self, forKey: .distinguished)
        edited = try container.decodeIfPresent(EditedData.self, forKey: .edited)
        saved = try container.decodeIfPresent(Bool.self, forKey: .saved) ?? false
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        clicked = try container.decodeIfPresent(Bool.self, forKey: .clicked) ?? false
        visited = try container.decodeIfPresent(Bool.self, forKey: .visited) ?? false
        ups = try container.decodeIfPresent(Int.self, forKey: .ups) ?? 0
        downs = try container.decodeIfPresent(Int.self, forKey: .downs) ?? 0
        likes = try container.decodeIfPresent(Bool.self, forKey: .likes)
        
        displayScore = score
        if let likes = likes {
            currentVoteState = likes ? .upvoted : .downvoted
        } else {
            currentVoteState = .neutral
        }
    }
    
    var displaySubreddit: String {
        subredditNamePrefixed ?? "r/\(subreddit)"
    }
    
    var createdDate: Date {
        if let createdUtc = createdUtc {
            return Date(timeIntervalSince1970: createdUtc)
        } else if let created = created {
            return Date(timeIntervalSince1970: created)
        } else {
            return Date()
        }
    }
    
    var timeAgo: String {
        guard let createdUtc = createdUtc ?? created else {
            return "now"
        }
        
        let now = Date()
        let createdDate = Date(timeIntervalSince1970: createdUtc)
        let timeInterval = now.timeIntervalSince(createdDate)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 2592000 {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return "\(months)mo"
        } else {
            let years = Int(timeInterval / 31536000)
            return "\(years)y"
        }
    }
    
    var scoreText: String {
        let score = max(0, displayScore) // Ensure score doesn't go below 0
        if score >= 1000 {
            let kScore = Double(score) / 1000.0
            return String(format: "%.1fk", kScore)
        } else {
            return String(score)
        }
    }
    
    var commentsText: String {
        if numComments >= 1000 {
            let kComments = Double(numComments) / 1000.0
            return String(format: "%.1fk", kComments)
        } else {
            return String(numComments)
        }
    }
    
    var postType: PostType {
        if isGalleryPost {
            return .gallery
        }
        
        if isYouTubeLink {
            return .youtube
        }
        
        if isRedGifsLink {
            return .video
        }
        
        if isVideo || hasVideoURL {
            return .video
        } else if let hint = postHint {
            switch hint {
            case "image":
                if isGifContent {
                    return .gif
                } else {
                    return .image
                }
            case "link":
                if preview != nil && !isDirectImageURL(url ?? "") {
                    return .link
                } else if isDirectImageURL(url ?? "") {
                    return .image
                } else {
                    return .link
                }
            case "hosted:video":
                return .video
            case "rich:video":
                return .video
            default:
                return .text
            }
        } else if isGifContent {
            return .gif
        } else if !selftext.isNilOrEmpty {
            return .text
        } else if let domain = domain, domain != "self.\(subreddit)" {
            return .link
        } else {
            return .text
        }
    }
    
    private var hasVideoURL: Bool {
        if let url = url {
            return url.contains("v.redd.it") || 
                   url.contains("vimeo.com") ||
                   url.contains("redgifs.com") ||
                   url.contains("v3.redgifs.com") ||
                   url.lowercased().contains(".mp4") ||
                   url.lowercased().contains(".mov") ||
                   url.lowercased().contains(".webm")
        }
        return false
    }
    
    var isYouTubeLink: Bool {
        guard let url = url else { return false }
        return url.contains("youtu.be") || url.contains("youtube.com")
    }
    
    var isRedGifsLink: Bool {
        guard let url = url else { return false }
        return url.contains("redgifs.com") || url.contains("v3.redgifs.com")
    }
    
    var imageURL: String? {
        if let preview = preview,
           let firstImage = preview.images.first {
            
            let allSources = [firstImage.source] + firstImage.resolutions
            let optimalSource = allSources.first { $0.width >= 1080 } ?? 
                              allSources.max { $0.width < $1.width } ?? 
                              firstImage.source
            
            let sourceURL = optimalSource.url.replacingOccurrences(of: "&amp;", with: "&")
            return sourceURL
        }
        
        if let url = url, isDirectImageURL(url) {
            let cleanURL = url.replacingOccurrences(of: "&amp;", with: "&")
            return cleanURL
        }
        
        if let thumb = thumbnail,
           thumb != "self" && thumb != "default" && thumb != "nsfw" && thumb != "spoiler" && thumb != "",
           thumb.hasPrefix("http") && (thumb.contains("redd.it") || thumb.contains("imgur")) {
            let cleanURL = thumb.replacingOccurrences(of: "&amp;", with: "&")
            return cleanURL
        }
        
        return nil
    }
    
    var imageDimensions: CGSize? {
        if let preview = preview,
           let firstImage = preview.images.first {
            let allSources = [firstImage.source] + firstImage.resolutions
            let optimalSource = allSources.first { $0.width >= 1080 } ?? 
                              allSources.max { $0.width < $1.width } ?? 
                              firstImage.source
            return CGSize(width: optimalSource.width, height: optimalSource.height)
        }
        return nil
    }
    
    var videoThumbnailDimensions: CGSize? {
        if isVideo {
            if isRedGifsLink,
               let media = media ?? secureMedia,
               let oembed = media.oembed,
               let width = oembed.width,
               let height = oembed.height {
                return CGSize(width: width, height: height)
            }
            
            if let preview = preview,
               let firstImage = preview.images.first {
                let allSources = [firstImage.source] + firstImage.resolutions
                let goodSource = allSources.first { $0.width >= 640 && $0.width <= 1080 } ?? 
                               allSources.last ?? firstImage.source
                return CGSize(width: goodSource.width, height: goodSource.height)
            }
        }
        return nil
    }
    
    var videoURL: String? {
        if let media = media ?? secureMedia,
           let redditVideo = media.redditVideo {
            return redditVideo.hlsUrl ?? redditVideo.fallbackUrl
        }
        
        if isRedGifsLink {
            // Try to get video ID from oembed thumbnail URL first (most reliable), then fallback to main URL
            var videoId = ""
            
            if let media = media ?? secureMedia,
               let oembed = media.oembed,
               let thumbnailUrl = oembed.thumbnailUrl {
                videoId = extractRedGifsIdFromThumbnail(thumbnailUrl)
            }
            
            if videoId.isEmpty, let url = url {
                videoId = extractRedGifsVideoId(from: url)
            }
            
            if !videoId.isEmpty {
                return "https://files.redgifs.com/\(videoId).mp4"
            }
        }
        
        if let url = url, url.contains("v.redd.it") {
            if !url.hasSuffix("/") {
                return "\(url)/DASH_720.mp4"
            }
        }
        
        return nil
    }
    
    var videoThumbnailURL: String? {
        if isVideo {
            if isRedGifsLink,
               let media = media ?? secureMedia,
               let oembed = media.oembed,
               let thumbnailUrl = oembed.thumbnailUrl {
                return thumbnailUrl.replacingOccurrences(of: "&amp;", with: "&")
            }
            
            if let preview = preview,
               let firstImage = preview.images.first {
                let allSources = [firstImage.source] + firstImage.resolutions
                let goodSource = allSources.first { $0.width >= 640 && $0.width <= 1080 } ?? 
                               allSources.last ?? firstImage.source
                let url = goodSource.url.replacingOccurrences(of: "&amp;", with: "&")
                return url
            }
            
            if let thumb = thumbnail,
               thumb != "self" && thumb != "default" && thumb != "nsfw" && thumb != "spoiler" && thumb != "",
               thumb.hasPrefix("http") {
                let url = thumb.replacingOccurrences(of: "&amp;", with: "&")
                return url
            }
            
        }
        return nil
    }
    
    var hasContent: Bool {
        return !selftext.isNilOrEmpty
    }
    
    var isGalleryPost: Bool {
        if let isGallery = isGallery, isGallery {
            return true
        }
        
        if let mediaMetadata = mediaMetadata, !mediaMetadata.isEmpty {
            return true
        }
        
        if let url = url, url.contains("/gallery/") {
            return true
        }
        
        if let domain = domain, domain.contains("reddit.com") && url?.contains("/gallery/") == true {
            return true
        }
        
        if postHint == "image" && preview?.images.count ?? 0 > 1 {
            return true
        }
        
        if let preview = preview, preview.images.count > 1 {
            return true
        }
        
        return false
    }
    
    var galleryImages: [GalleryImage] {
        if let mediaMetadata = mediaMetadata, !mediaMetadata.isEmpty {
            return Array(mediaMetadata.enumerated()).compactMap { (index, keyValue) in
                let (_, metadata) = keyValue
                guard let source = metadata.s,
                      let urlString = source.u,
                      let width = source.x,
                      let height = source.y else {
                    return nil
                }
                
                let cleanURL = urlString.replacingOccurrences(of: "&amp;", with: "&")
                
                return GalleryImage(
                    id: "\(id)_\(index)",
                    url: cleanURL,
                    width: width,
                    height: height,
                    index: index
                )
            }
        }
        
        guard let preview = preview else { return [] }
        
        return preview.images.enumerated().map { index, previewImage in
            let allSources = [previewImage.source] + previewImage.resolutions
            let optimalSource = allSources.first { $0.width >= 1080 } ?? 
                              allSources.max { $0.width < $1.width } ?? 
                              previewImage.source
            
            let cleanURL = optimalSource.url.replacingOccurrences(of: "&amp;", with: "&")
            
            return GalleryImage(
                id: "\(id)_\(index)",
                url: cleanURL,
                width: optimalSource.width,
                height: optimalSource.height,
                index: index
            )
        }
    }
    
    var galleryCount: Int {
        return galleryImages.count
    }
    
    var isGifContent: Bool {
        if let media = media ?? secureMedia,
           let redditVideo = media.redditVideo {
            return redditVideo.isGif
        }
        
        if let imageURL = imageURL {
            return imageURL.lowercased().contains(".gif") || 
                   imageURL.lowercased().contains("gif") ||
                   imageURL.lowercased().contains("giphy")
        }
        
        if let url = url {
            return url.lowercased().contains(".gif") || 
                   url.lowercased().contains("gif") ||
                   url.lowercased().contains("giphy")
        }
        
        return false
    }
    
    var gifURL: String? {
        if let media = media ?? secureMedia,
           let redditVideo = media.redditVideo,
           redditVideo.isGif {
            return redditVideo.fallbackUrl
        }
        
        if let url = url, url.lowercased().contains(".gif") {
            return url
        }
        
        return imageURL
    }
    
    var fullURL: String {
        if let url = url, url.hasPrefix("http") {
            return url
        } else {
            return "https://reddit.com\(permalink)"
        }
    }
    
    var permalinkURL: String {
        return "https://reddit.com\(permalink)"
    }
    
    var canVote: Bool {
        return !archived && !locked
    }
    
    mutating func applyVote(_ voteState: VoteState) {
        let oldState = currentVoteState
        currentVoteState = voteState
        
        switch (oldState, voteState) {
        case (.neutral, .upvoted):
            displayScore += 1
        case (.neutral, .downvoted):
            displayScore -= 1
        case (.upvoted, .neutral):
            displayScore -= 1
        case (.upvoted, .downvoted):
            displayScore -= 2
        case (.downvoted, .neutral):
            displayScore += 1
        case (.downvoted, .upvoted):
            displayScore += 2
        case (.neutral, .neutral), (.upvoted, .upvoted), (.downvoted, .downvoted):
            break // No change
        }
    }
    
    mutating func revertVote(to originalState: VoteState, originalScore: Int) {
        currentVoteState = originalState
        displayScore = originalScore
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RedditPost, rhs: RedditPost) -> Bool {
        return lhs.id == rhs.id
    }
    
    private func isDirectImageURL(_ url: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
        let lowercaseURL = url.lowercased()
        
        if imageExtensions.contains(where: { lowercaseURL.contains($0) }) {
            return true
        }
        
        let imageHosts = ["i.imgur.com", "i.redd.it", "preview.redd.it", "external-preview.redd.it", "imgur.com"]
        return imageHosts.contains { lowercaseURL.contains($0) }
    }
    
    private func extractRedGifsVideoId(from url: String) -> String {
        // Extract video ID from RedGifs URLs
        // Examples:
        // https://redgifs.com/watch/anxiousrigidilladopsis -> anxiousrigidilladopsis
        // https://v3.redgifs.com/watch/masculineimmensebluejay -> masculineimmensebluejay
        
        let patterns = [
            #"redgifs\.com/watch/([a-zA-Z0-9]+)"#,
            #"v3\.redgifs\.com/watch/([a-zA-Z0-9]+)"#
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = url as NSString
                if let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let videoId = nsString.substring(with: match.range(at: 1))
                    // RedGifs uses capitalized IDs for file URLs
                    return capitalizeRedGifsId(videoId)
                }
            } catch {
                continue
            }
        }
        
        return ""
    }
    
    private func capitalizeRedGifsId(_ id: String) -> String {
        // RedGifs video IDs need to match the exact case used in the media URLs
        // Based on examples: "immenserosybrownthoroughbred" -> "ImmenseRosybrownThoroughbred"
        // The pattern seems to be: capitalize first letter and keep the rest as lowercase
        
        // Handle known patterns from the examples
        let lowercaseId = id.lowercased()
        
        // Simple capitalization: just capitalize the first letter
        if !lowercaseId.isEmpty {
            return lowercaseId.prefix(1).uppercased() + lowercaseId.dropFirst()
        }
        
        return id
    }
    
    private func extractRedGifsIdFromThumbnail(_ thumbnailUrl: String) -> String {
        // Extract video ID from thumbnail URLs like:
        // https://media.redgifs.com/ImmenseRosybrownThoroughbred-poster.jpg
        // https://media.redgifs.com/MasculineImmenseBluejay-poster.jpg
        // https://media.redgifs.com/AnxiousRigidIlladopsis-poster.jpg
        
        do {
            let pattern = #"media\.redgifs\.com/([A-Za-z0-9]+)-poster\.(jpg|png)"#
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = thumbnailUrl as NSString
            if let match = regex.firstMatch(in: thumbnailUrl, options: [], range: NSRange(location: 0, length: nsString.length)) {
                return nsString.substring(with: match.range(at: 1))
            }
        } catch {
            // Ignore regex errors
        }
        
        return ""
    }
    
    /// Converts a clean post ID back to Reddit API format (t3_postId)
    /// Used when making API calls that require the prefixed format
    var postFullname: String {
        return "t3_\(id)"
    }
}

enum PostType {
    case text
    case image
    case gif
    case video
    case youtube
    case gallery
    case link
    
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .gif: return "play.rectangle.fill"
        case .video: return "play.rectangle"
        case .youtube: return "play.rectangle.on.rectangle"
        case .gallery: return "photo.stack"
        case .link: return "link"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .gif: return "GIF"
        case .video: return "Video"
        case .youtube: return "YouTube"
        case .gallery: return "Gallery"
        case .link: return "Link"
        }
    }
}

struct PreviewData: Codable {
    let images: [PreviewImage]
    let enabled: Bool
    
    struct PreviewImage: Codable {
        let source: ImageSource
        let resolutions: [ImageSource]
        let id: String
        
        struct ImageSource: Codable {
            let url: String
            let width: Int
            let height: Int
        }
    }
}

struct MediaData: Codable {
    let redditVideo: RedditVideo?
    let oembed: OEmbed?
    
    enum CodingKeys: String, CodingKey {
        case redditVideo = "reddit_video"
        case oembed
    }
    
    struct RedditVideo: Codable {
        let fallbackUrl: String?
        let height: Int
        let width: Int
        let hlsUrl: String?
        let dashUrl: String?
        let duration: Int?
        let isGif: Bool
        
        enum CodingKeys: String, CodingKey {
            case fallbackUrl = "fallback_url"
            case height, width, duration
            case hlsUrl = "hls_url"
            case dashUrl = "dash_url"
            case isGif = "is_gif"
        }
    }
    
    struct OEmbed: Codable {
        let providerUrl: String?
        let description: String?
        let title: String?
        let type: String?
        let thumbnailWidth: Int?
        let height: Int?
        let width: Int?
        let html: String?
        let version: String?
        let providerName: String?
        let thumbnailUrl: String?
        let thumbnailHeight: Int?
        
        enum CodingKeys: String, CodingKey {
            case providerUrl = "provider_url"
            case description, title, type, height, width, html, version
            case thumbnailWidth = "thumbnail_width"
            case providerName = "provider_name"
            case thumbnailUrl = "thumbnail_url"
            case thumbnailHeight = "thumbnail_height"
        }
    }
}

struct MediaEmbed: Codable {
    let content: String?
    let width: Int?
    let scrolling: Bool?
    let height: Int?
}

struct MediaMetadataItem: Codable {
    let status: String?
    let e: String?
    let m: String?
    let s: MediaSource?
    
    struct MediaSource: Codable {
        let y: Int?
        let x: Int?
        let u: String?
    }
}

struct GalleryImage: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let index: Int
    
    var dimensions: CGSize {
        return CGSize(width: width, height: height)
    }
}

enum EditedData: Codable {
    case timestamp(Double)
    case boolean(Bool)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let timestamp = try? container.decode(Double.self) {
            self = .timestamp(timestamp)
        } else if let boolean = try? container.decode(Bool.self) {
            self = .boolean(boolean)
        } else {
            self = .boolean(false)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .timestamp(let timestamp):
            try container.encode(timestamp)
        case .boolean(let boolean):
            try container.encode(boolean)
        }
    }
    
    var isEdited: Bool {
        switch self {
        case .timestamp:
            return true
        case .boolean(let edited):
            return edited
        }
    }
}

struct PostResponse: Codable {
    let data: PostListData
}

struct PostListData: Codable {
    let children: [PostChild]
    let after: String?
    let before: String?
    let dist: Int?
    let modhash: String?
}

struct PostChild: Codable {
    let kind: String
    let data: RedditPost?
    
    init(kind: String, data: RedditPost?) {
        self.kind = kind
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        kind = try container.decode(String.self, forKey: .kind)
        
        if kind == "t3" {
            data = try container.decode(RedditPost.self, forKey: .data)
        } else {
            data = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(data, forKey: .data)
    }
    
    enum CodingKeys: String, CodingKey {
        case kind, data
    }
}

extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

enum PostSort: String, CaseIterable {
    case hot = "hot"
    case new = "new" 
    case top = "top"
    case rising = "rising"
    
    var displayName: String {
        switch self {
        case .hot: return "Hot"
        case .new: return "New"
        case .top: return "Top"
        case .rising: return "Rising"
        }
    }
    
    var supportsTimeFrame: Bool {
        switch self {
        case .top: return true
        default: return false
        }
    }
}

enum TopTimeFrame: String, CaseIterable {
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .hour: return "Past Hour"
        case .day: return "Past 24 Hours"
        case .week: return "Past Week"
        case .month: return "Past Month"
        case .year: return "Past Year"
        case .all: return "All Time"
        }
    }
}
