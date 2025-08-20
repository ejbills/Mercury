//
//  RedditAPIManager.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation
import Combine

/// Main coordinator class that manages all Reddit services
@Observable
class RedditAPIManager {
    // Core services
    let authService: AuthenticationService
    let contentService: ContentService
    let userService: UserService
    let searchService: SearchService
    let commentsService: CommentsService
    let inboxService: InboxService
    
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // MARK: - Initialization
    
    init() {
        // Initialize authentication service first
        self.authService = AuthenticationService()
        
        // Initialize other services with auth service reference
        self.contentService = ContentService(authService: authService)
        self.userService = UserService(authService: authService)
        self.searchService = SearchService(authService: authService)
        self.commentsService = CommentsService(authService: authService)
        self.inboxService = InboxService(authService: authService)
    }
    
    // MARK: - Authentication Methods (Delegated)
    
    func setClientId(_ clientId: String) {
        authService.setClientId(clientId)
    }
    
    func startOAuthFlow() {
        authService.startOAuthFlow()
    }
    
    func validateCredentials() async {
        await authService.validateCredentials()
    }
    
    func clearStoredCredentials() {
        authService.clearStoredCredentials()
    }
    
    // MARK: - Content Methods (Delegated)
    
    func fetchSubscribedSubreddits() async throws -> [Subreddit] {
        try await contentService.fetchSubscribedSubreddits()
    }
    
    func fetchSubredditPosts(subreddit: String, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchSubredditPosts(subreddit: subreddit, after: after, limit: limit)
    }
    
    func fetchHomeFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchHomeFeed(after: after, limit: limit)
    }
    
    func fetchPopularFeed(after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await contentService.fetchPopularFeed(after: after, limit: limit)
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
    
    // MARK: - User Methods (Delegated)
    
    func fetchUserProfile(username: String) async throws -> UserProfile {
        try await userService.fetchUserProfile(username: username)
    }
    
    func fetchUserPosts(username: String, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await userService.fetchUserPosts(username: username, after: after, limit: limit)
    }
    
    func fetchUserComments(username: String, after: String? = nil, limit: Int = 25) async throws -> UserCommentsResponse {
        try await userService.fetchUserComments(username: username, after: after, limit: limit)
    }
    
    // MARK: - Search Methods (Delegated)
    
    func searchSubreddits(query: String, limit: Int = 25) async throws -> [Subreddit] {
        try await searchService.searchSubreddits(query: query, limit: limit)
    }
    
    func searchPosts(query: String, subreddit: String? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await searchService.searchPosts(query: query, subreddit: subreddit, after: after, limit: limit)
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
    
    func replyToMessage(fullname: String, text: String) async throws {
        try await inboxService.replyToMessage(fullname: fullname, text: text)
    }
    
    // Compose a new private message to a user
    func composePrivateMessage(to username: String, subject: String, text: String) async throws {
        try await inboxService.composeMessage(to: username, subject: subject, text: text)
    }

    // Submit a new comment or reply
    func submitComment(parentFullname: String, text: String) async throws -> RedditComment {
        try await commentsService.submitComment(parentFullname: parentFullname, text: text)
    }

    // Delete an existing comment (must be authored by the current user)
    func deleteComment(commentId: String) async throws {
        try await commentsService.deleteComment(commentId: commentId)
    }
}
