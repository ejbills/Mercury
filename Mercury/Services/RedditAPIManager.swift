import Foundation
import Combine
import UIKit
import Defaults

/// Main coordinator class that manages all Reddit services
@Observable
class RedditAPIManager {
    let authService: AuthenticationService
    let contentService: ContentService
    let userService: UserService
    let searchService: SearchService
    let commentsService: CommentsService
    let inboxService: InboxService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Simple caches
    private var subredditCache: [Subreddit]? = nil
    private var subredditCacheDate: Date? = nil
    private var multiCache: [MultiReddit]? = nil
    private var multiCacheDate: Date? = nil
    
    // MARK: - Computed Properties (for backward compatibility)
    
    var apiStatus: AuthenticationService.APIStatus {
        authService.apiStatus
    }
    
    var userInfo: RedditUser? {
        authService.userInfo
    }
    
    var errorMessage: String? {
        authService.errorMessage
    }
    
    var accessToken: String? {
        authService.accessToken
    }
    
    var hasStoredCredentials: Bool {
        authService.hasStoredCredentials
    }

    // MARK: - Multi-account exposure
    var storedAccounts: [StoredAccount] { authService.storedAccounts }
    var activeUsername: String? { authService.activeUsername }

    func performUsingAccount<T>(username: String, operation: @escaping () async throws -> T) async throws -> T {
        try await authService.performUsingAccount(username: username, body: operation)
    }

    func availableAccountUsernames() -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        func append(_ username: String) {
            let key = username.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(username)
            }
        }

        if let active = userInfo?.name ?? activeUsername {
            append(active)
        }

        let sortedAccounts = storedAccounts.sorted { $0.lastUpdated > $1.lastUpdated }
        for account in sortedAccounts {
            append(account.username)
        }

        return result
    }

    func switchToAccount(username: String) async {
        // Clear caches before switching accounts
        clearSubredditCaches()
        await authService.switchToAccount(username: username)
    }

    func removeAccount(username: String) {
        authService.removeAccount(username: username)
    }

    // MARK: - Cache Management

    func clearSubredditCaches() {
        subredditCache = nil
        subredditCacheDate = nil
        multiCache = nil
        multiCacheDate = nil
        Defaults[.cachedSubscribedSubredditsData] = nil
        Defaults[.cachedSubscribedSubredditsDate] = nil
        Defaults[.cachedUserMultiredditsData] = nil
        Defaults[.cachedUserMultiredditsDate] = nil
        Defaults[.cachedUserMultiredditsUsername] = nil
    }
    
    // MARK: - Initialization
    
    init() {
        self.authService = AuthenticationService()
        
        self.contentService = ContentService(authService: authService)
        self.userService = UserService(authService: authService)
        self.searchService = SearchService(authService: authService)
        self.commentsService = CommentsService(authService: authService)
        self.inboxService = InboxService(authService: authService)

        // Load cached subreddits from Defaults for quicker launch
        if let data = Defaults[.cachedSubscribedSubredditsData] {
            if let decoded = try? JSONDecoder().decode([Subreddit].self, from: data) {
                self.subredditCache = decoded
                self.subredditCacheDate = Defaults[.cachedSubscribedSubredditsDate]
            }
        }

        // Load cached multireddits only if username matches
        if let cachedUser = Defaults[.cachedUserMultiredditsUsername],
           let currentUser = authService.userInfo?.name,
           cachedUser == currentUser,
           let data = Defaults[.cachedUserMultiredditsData],
           let decoded = try? JSONDecoder().decode([MultiReddit].self, from: data) {
            self.multiCache = decoded
            self.multiCacheDate = Defaults[.cachedUserMultiredditsDate]
        }
    }
    
    // MARK: - Authentication Methods (Delegated)
    
    func setClientId(_ clientId: String) {
        authService.setClientId(clientId)
    }
    
    func startOAuthFlow() {
        authService.startOAuthFlow()
    }
    
    func startOAuthFlow(clientId: String) {
        authService.startOAuthFlow(clientId: clientId)
    }
    
    func validateCredentials() async {
        await authService.validateCredentials()
    }
    
    func clearStoredCredentials() {
        authService.clearStoredCredentials()
    }

    // Helpers for account flows
    func buildAuthorizationURL(for clientId: String) -> URL? {
        authService.buildAuthorizationURL(for: clientId)
    }
    
    // MARK: - Content Methods (Delegated)
    
    func fetchSubscribedSubreddits() async throws -> [Subreddit] {
        try await contentService.fetchSubscribedSubreddits()
    }

    // Cached variant for subscribed subreddits
    func fetchSubscribedSubredditsCached(forceRefresh: Bool = false) async throws -> [Subreddit] {
        // Serve from in-memory cache if present and not forcing refresh
        if !forceRefresh, let cached = subredditCache, !cached.isEmpty {
            return cached
        }
        // Fall back to persisted cache if available (and not forcing refresh)
        if !forceRefresh, subredditCache == nil, let data = Defaults[.cachedSubscribedSubredditsData],
           let decoded = try? JSONDecoder().decode([Subreddit].self, from: data) {
            self.subredditCache = decoded
            self.subredditCacheDate = Defaults[.cachedSubscribedSubredditsDate]
            return decoded
        }

        let fetched = try await contentService.fetchSubscribedSubreddits()
        // Update caches
        self.subredditCache = fetched
        self.subredditCacheDate = Date()
        if let data = try? JSONEncoder().encode(fetched) {
            Defaults[.cachedSubscribedSubredditsData] = data
            Defaults[.cachedSubscribedSubredditsDate] = self.subredditCacheDate
        }
        return fetched
    }
    
    func fetchSubredditPosts(subreddit: String, sort: PostSort = .hot, timeFrame: TopTimeFrame? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchSubredditPosts(subreddit: subreddit, sort: sort, timeFrame: timeFrame, after: after, limit: limit)
    }
    
    func fetchHomeFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchHomeFeed(after: after, limit: limit)
    }
    
    func fetchPopularFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchPopularFeed(after: after, limit: limit)
    }
    
    func fetchSavedPosts(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchSavedPosts(after: after, limit: limit)
    }

    func submitTextPost(subreddit: String, title: String, text: String, flairId: String? = nil, flairText: String? = nil) async throws {
        try await contentService.submitTextPost(subreddit: subreddit, title: title, text: text, flairId: flairId, flairText: flairText)
    }

    func submitLinkPost(subreddit: String, title: String, url: String, flairId: String? = nil, flairText: String? = nil) async throws {
        try await contentService.submitLinkPost(subreddit: subreddit, title: title, url: url, flairId: flairId, flairText: flairText)
    }

    func submitImagePost(subreddit: String, title: String, caption: String?, images: [UIImage], flairId: String? = nil, flairText: String? = nil) async throws {
        try await contentService.submitImagePost(subreddit: subreddit, title: title, caption: caption, images: images, flairId: flairId, flairText: flairText)
    }

    // MARK: - Subreddit actions

    func subscribe(to subreddit: String) async throws {
        try await contentService.subscribe(to: subreddit)
    }

    func unsubscribe(from subreddit: String) async throws {
        try await contentService.unsubscribe(from: subreddit)
    }

    func fetchSubredditAbout(subreddit: String) async throws -> Subreddit {
        try await contentService.fetchSubredditAbout(subreddit: subreddit)
    }
    
    func fetchPostsByFullnames(_ fullnames: [String]) async throws -> [RedditPost] {
        try await contentService.fetchPostsByFullnames(fullnames)
    }
    
    func voteOnPost(postId: String, voteDirection: VoteDirection) async throws {
        try await contentService.voteOnPost(postId: postId, voteDirection: voteDirection)
    }
    
    func savePost(postId: String) async throws {
        try await contentService.savePost(postId: postId)
    }
    
    func unsavePost(postId: String) async throws {
        try await contentService.unsavePost(postId: postId)
    }

    func hidePost(postId: String) async throws {
        try await contentService.hidePost(postId: postId)
    }

    func unhidePost(postId: String) async throws {
        try await contentService.unhidePost(postId: postId)
    }
    
    // MARK: - User Methods (Delegated)
    
    func fetchUserProfile(username: String) async throws -> UserProfile {
        try await userService.fetchUserProfile(username: username)
    }
    
    func fetchAvatarURL(username: String) async -> URL? {
        await userService.fetchAvatarURL(username: username)
    }
    
    func fetchUserPosts(username: String, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await userService.fetchUserPosts(username: username, after: after, limit: limit)
    }
    
    func fetchUserComments(username: String, after: String? = nil, limit: Int = 25) async throws -> UserCommentsResponse {
        try await userService.fetchUserComments(username: username, after: after, limit: limit)
    }
    
    func setUserFollow(username: String, follow: Bool) async throws {
        try await userService.setUserFollow(username: username, follow: follow)
    }
    
    // MARK: - Multireddits
    func fetchUserMultireddits() async throws -> [MultiReddit] {
        try await contentService.fetchUserMultireddits()
    }

    func fetchMultiPosts(username: String, multi: String, sort: PostSort = .hot, timeFrame: TopTimeFrame? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchMultiPosts(username: username, multi: multi, sort: sort, timeFrame: timeFrame, after: after, limit: limit)
    }

    func createMultireddit(displayName: String, subreddits: [String], descriptionMd: String? = nil) async throws -> MultiReddit {
        try await contentService.createMultireddit(displayName: displayName, subreddits: subreddits, descriptionMd: descriptionMd)
    }

    func updateMultireddit(username: String, name: String, displayName: String? = nil, subreddits: [String]? = nil, descriptionMd: String? = nil) async throws -> MultiReddit {
        try await contentService.updateMultireddit(username: username, name: name, displayName: displayName, subreddits: subreddits, descriptionMd: descriptionMd)
    }

    func deleteMultireddit(username: String, name: String) async throws {
        try await contentService.deleteMultireddit(username: username, name: name)
    }

    // Cached variant for user's multireddits
    func fetchUserMultiredditsCached(forceRefresh: Bool = false) async throws -> [MultiReddit] {
        let currentUser = authService.userInfo?.name
        // Serve in-memory cache if present and not forcing refresh
        if !forceRefresh, let cached = multiCache, !cached.isEmpty {
            return cached
        }
        // Serve persisted cache if present for this user
        if !forceRefresh,
           let cachedUser = Defaults[.cachedUserMultiredditsUsername],
           cachedUser == currentUser,
           let data = Defaults[.cachedUserMultiredditsData],
           let decoded = try? JSONDecoder().decode([MultiReddit].self, from: data) {
            self.multiCache = decoded
            self.multiCacheDate = Defaults[.cachedUserMultiredditsDate]
            return decoded
        }

        let fetched = try await contentService.fetchUserMultireddits()
        self.multiCache = fetched
        self.multiCacheDate = Date()
        if let data = try? JSONEncoder().encode(fetched) {
            Defaults[.cachedUserMultiredditsData] = data
            Defaults[.cachedUserMultiredditsDate] = self.multiCacheDate
            Defaults[.cachedUserMultiredditsUsername] = currentUser
        }
        return fetched
    }
    
    // MARK: - Search Methods (Delegated)
    
    func searchSubreddits(query: String, limit: Int = 25) async throws -> [Subreddit] {
        try await searchService.searchSubreddits(query: query, limit: limit)
    }
    
    func searchPosts(
        query: String,
        subreddit: String? = nil,
        after: String? = nil,
        limit: Int = 25,
        sort: String = "relevance",
        timeFrame: String? = nil
    ) async throws -> PostResponse {
        try await searchService.searchPosts(
            query: query,
            subreddit: subreddit,
            after: after,
            limit: limit,
            sort: sort,
            timeFrame: timeFrame
        )
    }
    
    // MARK: - Comments Methods (Delegated)
    
    func fetchPostComments(postId: String, sort: CommentSort = .best, limit: Int = 50, after: String? = nil, focusCommentId: String? = nil, context: Int? = nil) async throws -> [CommentResponse] {
        try await commentsService.fetchPostComments(postId: postId, sort: sort, limit: limit, after: after, focusCommentId: focusCommentId, context: context)
    }
    
    func fetchMoreComments(postId: String, commentIds: [String], sort: CommentSort = .best) async throws -> [RedditComment] {
        try await commentsService.fetchMoreComments(postId: postId, commentIds: commentIds, sort: sort)
    }
    
    func voteOnComment(commentId: String, voteDirection: VoteDirection) async throws {
        try await commentsService.voteOnComment(commentId: commentId, voteDirection: voteDirection)
    }
    
    func saveComment(commentId: String) async throws {
        try await commentsService.saveComment(commentId: commentId)
    }
    
    func unsaveComment(commentId: String) async throws {
        try await commentsService.unsaveComment(commentId: commentId)
    }
    
    // MARK: - Inbox Methods (Delegated)
    
    func fetchInbox(category: InboxService.Category, after: String? = nil, limit: Int = 25) async throws -> InboxService.Page {
        try await inboxService.fetch(category: category, after: after, limit: limit)
    }
    
    func fetchPrivateMessagesRaw(after: String? = nil, limit: Int = 50) async throws -> (items: [RawMessage], after: String?) {
        try await inboxService.fetchPrivateMessagesRaw(after: after, limit: limit)
    }
    
    func markMessagesRead(fullnames: [String]) async throws {
        try await inboxService.markMessagesRead(fullnames: fullnames)
    }

    func markAllInboxRead(for category: InboxService.Category) async throws {
        try await inboxService.markAllRead(for: category)
    }
    
    func replyToMessage(fullname: String, text: String) async throws {
        try await inboxService.replyToMessage(fullname: fullname, text: text)
    }
    
    func composePrivateMessage(to username: String, subject: String, text: String) async throws {
        try await inboxService.composeMessage(to: username, subject: subject, text: text)
    }

    func submitComment(parentFullname: String, text: String) async throws -> RedditComment {
        try await commentsService.submitComment(parentFullname: parentFullname, text: text)
    }

    func deleteComment(commentId: String) async throws {
        try await commentsService.deleteComment(commentId: commentId)
    }

    // MARK: - Flairs + Post Requirements
    func fetchLinkFlairs(subreddit: String) async throws -> [LinkFlair] {
        try await contentService.fetchLinkFlairs(subreddit: subreddit)
    }

    func fetchPostRequirements(subreddit: String, postType: String? = nil) async throws -> PostRequirements? {
        try await contentService.fetchPostRequirements(subreddit: subreddit, postType: postType)
    }

    // MARK: - Flair Selector / SelectFlair
    func fetchFlairSelector(subreddit: String, linkFullname: String) async throws -> [LinkFlair] {
        try await contentService.fetchFlairSelector(subreddit: subreddit, linkFullname: linkFullname)
    }

    func selectFlair(subreddit: String, linkFullname: String, flairTemplateId: String, text: String? = nil) async throws {
        try await contentService.selectFlair(subreddit: subreddit, linkFullname: linkFullname, flairTemplateId: flairTemplateId, text: text)
    }
}
