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
    
    // MARK: - Search Methods (Delegated)
    
    func searchSubreddits(query: String, limit: Int = 25) async throws -> [Subreddit] {
        try await searchService.searchSubreddits(query: query, limit: limit)
    }
    
    func searchPosts(query: String, subreddit: String? = nil, after: String? = nil, limit: Int = 25) async throws -> PostResponse {
        try await searchService.searchPosts(query: query, subreddit: subreddit, after: after, limit: limit)
    }
}
