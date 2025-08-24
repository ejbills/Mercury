import SwiftUI
import Foundation

@MainActor
@Observable
class ProfileViewModel {
    let username: String
    let redditAPI: RedditAPIManager
    
    // Profile data
    private(set) var profile: UserProfile?
    private(set) var posts: [RedditPost] = []
    private(set) var comments: [RedditComment] = []
    
    // Pagination
    private(set) var postsAfter: String?
    private(set) var commentsAfter: String?
    
    // Loading states
    private(set) var isLoading = false
    private(set) var isLoadingMorePosts = false
    private(set) var isLoadingMoreComments = false
    private(set) var errorMessage: String?
    
    // Comment context
    private(set) var commentPostMap: [String: RedditPost] = [:]
    private(set) var commentsContextReady = false
    
    // Header avatar fallback
    private(set) var headerAvatarURL: URL?
    
    init(username: String, redditAPI: RedditAPIManager) {
        self.username = username
        self.redditAPI = redditAPI
    }
    
    func initialLoad() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            async let p = redditAPI.fetchUserProfile(username: username)
            async let postsResp = redditAPI.fetchUserPosts(username: username, after: nil, limit: 25)
            async let commentsResp = redditAPI.fetchUserComments(username: username, after: nil, limit: 25)
            
            let (profile, postsResponse, commentsResponse) = try await (p, postsResp, commentsResp)
            let enrichedPosts = postsResponse.data.children.compactMap { $0.data }
            let enrichedComments = commentsResponse.data.children.compactMap { child in
                if case .comment(let c) = child.data { return c } else { return nil }
            }
            
            let derivedAvatarURL: URL? = (
                enrichedPosts.first(where: { $0.authorIconURL != nil })?.authorIconURL ??
                enrichedComments.first(where: { $0.authorIconURL != nil })?.authorIconURL
            )
            
            self.profile = profile
            self.posts = enrichedPosts
            self.postsAfter = postsResponse.data.after
            self.comments = enrichedComments
            self.commentsAfter = commentsResponse.data.after
            
            if self.headerAvatarURL == nil, profile.profileIconURL == nil, let d = derivedAvatarURL {
                self.headerAvatarURL = d
            }
            
            // Fetch avatar if still needed
            if self.headerAvatarURL == nil && profile.profileIconURL == nil {
                if let fetched = await redditAPI.fetchAvatarURL(username: username) {
                    self.headerAvatarURL = fetched
                }
            }
            
            await ensurePostsForComments(comments)
            self.commentsContextReady = true
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func refreshAll() async {
        errorMessage = nil
        postsAfter = nil
        commentsAfter = nil
        
        do {
            async let p = redditAPI.fetchUserProfile(username: username)
            async let postsResp = redditAPI.fetchUserPosts(username: username, after: nil, limit: 25)
            async let commentsResp = redditAPI.fetchUserComments(username: username, after: nil, limit: 25)
            
            let (profile, postsResponse, commentsResponse) = try await (p, postsResp, commentsResp)
            let enrichedPosts = postsResponse.data.children.compactMap { $0.data }
            let enrichedComments = commentsResponse.data.children.compactMap { child in
                if case .comment(let c) = child.data { return c } else { return nil }
            }
            
            let derivedAvatarURL: URL? = (
                enrichedPosts.first(where: { $0.authorIconURL != nil })?.authorIconURL ??
                enrichedComments.first(where: { $0.authorIconURL != nil })?.authorIconURL
            )
            
            self.profile = profile
            self.posts = enrichedPosts
            self.postsAfter = postsResponse.data.after
            self.comments = enrichedComments
            self.commentsAfter = commentsResponse.data.after
            
            if self.headerAvatarURL == nil, profile.profileIconURL == nil, let d = derivedAvatarURL {
                self.headerAvatarURL = d
            }
            
            self.errorMessage = nil // Clear any previous error on success
            
            // Fetch avatar if still needed
            if self.headerAvatarURL == nil && profile.profileIconURL == nil {
                if let fetched = await redditAPI.fetchAvatarURL(username: username) {
                    self.headerAvatarURL = fetched
                }
            }
            
            await ensurePostsForComments(enrichedComments)
            self.commentsContextReady = true
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadMorePosts() async {
        guard !isLoadingMorePosts, let after = postsAfter else { return }
        isLoadingMorePosts = true
        defer { isLoadingMorePosts = false }
        
        do {
            let response = try await redditAPI.fetchUserPosts(username: username, after: after, limit: 25)
            let newPosts = response.data.children.compactMap { $0.data }
            let unique = newPosts.filter { np in !posts.contains(where: { $0.id == np.id }) }
            posts.append(contentsOf: unique)
            postsAfter = response.data.after
        } catch {
            // Silently handle errors for pagination
        }
    }
    
    func loadMoreComments() async {
        guard !isLoadingMoreComments, let after = commentsAfter else { return }
        isLoadingMoreComments = true
        defer { isLoadingMoreComments = false }
        
        do {
            let response = try await redditAPI.fetchUserComments(username: username, after: after, limit: 25)
            let new = response.data.children.compactMap { child -> RedditComment? in
                if case .comment(let c) = child.data { return c } else { return nil }
            }
            let unique = new.filter { nc in !comments.contains(where: { $0.id == nc.id }) }
            await ensurePostsForComments(unique)
            comments.append(contentsOf: unique)
            commentsAfter = response.data.after
        } catch {
            // Silently handle errors for pagination
        }
    }
    
    private func ensurePostsForComments(_ comments: [RedditComment]) async {
        let needed = Set(comments.compactMap { linkKey(for: $0) }).filter { key in
            commentPostMap[key] == nil
        }
        guard !needed.isEmpty else { return }
        
        do {
            let posts = try await redditAPI.fetchPostsByFullnames(Array(needed))
            var map = commentPostMap
            for p in posts {
                map[p.fullname] = p
                map[p.id] = p
            }
            self.commentPostMap = map
        } catch {
            // Silently handle errors
        }
    }
    
    private func linkKey(for comment: RedditComment) -> String? {
        if let linkId = comment.linkId, !linkId.isEmpty { return linkId }
        let parts = comment.permalink.split(separator: "/")
        if let idx = parts.firstIndex(of: Substring("comments")), parts.count > idx + 1 {
            let postId = String(parts[idx + 1])
            return Fullname.post(postId)
        }
        return nil
    }
}