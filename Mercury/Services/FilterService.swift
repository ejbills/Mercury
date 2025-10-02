import Foundation
import Defaults

class FilterService {
    static let shared = FilterService()
    
    private init() {}
    
    
    func addBlockedKeyword(_ keyword: String) {
        var keywords = Defaults[.blockedKeywords]
        keywords.insert(keyword.lowercased())
        Defaults[.blockedKeywords] = keywords
    }
    
    func removeBlockedKeyword(_ keyword: String) {
        var keywords = Defaults[.blockedKeywords]
        keywords.remove(keyword.lowercased())
        Defaults[.blockedKeywords] = keywords
    }
    
    func isKeywordBlocked(_ keyword: String) -> Bool {
        guard Defaults[.keywordFilterEnabled] else { return false }
        return Defaults[.blockedKeywords].contains(keyword.lowercased())
    }
    
    
    func addBlockedUser(_ username: String) {
        var users = Defaults[.blockedUsers]
        users.insert(username.lowercased())
        Defaults[.blockedUsers] = users
    }
    
    func removeBlockedUser(_ username: String) {
        var users = Defaults[.blockedUsers]
        users.remove(username.lowercased())
        Defaults[.blockedUsers] = users
    }
    
    func isUserBlocked(_ username: String) -> Bool {
        guard Defaults[.userBlockingEnabled] else { return false }
        return Defaults[.blockedUsers].contains(username.lowercased())
    }
    
    
    func addBlockedSubreddit(_ subreddit: String) {
        var subreddits = Defaults[.blockedSubreddits]
        let cleanSubreddit = subreddit.replacingOccurrences(of: "r/", with: "").lowercased()
        subreddits.insert(cleanSubreddit)
        Defaults[.blockedSubreddits] = subreddits
    }
    
    func removeBlockedSubreddit(_ subreddit: String) {
        var subreddits = Defaults[.blockedSubreddits]
        let cleanSubreddit = subreddit.replacingOccurrences(of: "r/", with: "").lowercased()
        subreddits.remove(cleanSubreddit)
        Defaults[.blockedSubreddits] = subreddits
    }
    
    func isSubredditBlocked(_ subreddit: String) -> Bool {
        guard Defaults[.subredditBlockingEnabled] else { return false }
        let cleanSubreddit = subreddit.replacingOccurrences(of: "r/", with: "").lowercased()
        let patterns = Defaults[.blockedSubreddits]
        // Support wildcard matching (e.g., "pol*" matches "politics", "polls", etc.)
        return patterns.contains { pattern in
            wildcard(pattern: pattern, matches: cleanSubreddit)
        }
    }
    
    
    func shouldFilterPost(_ post: RedditPost) -> Bool {
        if isUserBlocked(post.author) {
            return true
        }
        
        if isSubredditBlocked(post.subreddit) {
            return true
        }
        
        if containsBlockedKeywords(in: post.title) || 
           containsBlockedKeywords(in: post.selftext ?? "") {
            return true
        }
        
        return false
    }
    
    func shouldFilterComment(_ comment: RedditComment) -> Bool {
        if isUserBlocked(comment.author) {
            return true
        }
        
        if containsBlockedKeywords(in: comment.body) {
            return true
        }
        
        return false
    }
    
    
    func filterPosts(_ posts: [RedditPost]) -> [RedditPost] {
        return posts.filter { !shouldFilterPost($0) }
    }
    
    func filterComments(_ comments: [RedditComment]) -> [RedditComment] {
        return comments.compactMap { comment in
            if shouldFilterComment(comment) {
                return nil
            }
            
            var filteredComment = comment
            if let replies = comment.replies {
                let replyComments = replies.comments
                let filteredReplies = filterComments(replyComments)
                
                if case .listing(let response) = replies {
                    let filteredChildren = filteredReplies.map { reply in
                        CommentChild(kind: "t1", data: .comment(reply))
                    }
                    let updatedData = CommentListData(
                        children: filteredChildren,
                        after: response.data.after,
                        before: response.data.before
                    )
                    let updatedResponse = CommentResponse(data: updatedData)
                    filteredComment.replies = .listing(updatedResponse)
                }
            }
            return filteredComment
        }
    }
    
    
    private func containsBlockedKeywords(in text: String) -> Bool {
        guard Defaults[.keywordFilterEnabled] else { return false }
        
        let lowercasedText = text.lowercased()
        return Defaults[.blockedKeywords].contains { keyword in
            lowercasedText.contains(keyword)
        }
    }

    // MARK: - Wildcard Matching Helper
    // Simple glob matching where '*' matches any sequence of characters.
    private func wildcard(pattern: String, matches text: String) -> Bool {
        let loweredPattern = pattern.lowercased()
        // Escape regex special chars, then replace escaped "*" with ".*"
        var regexPattern = NSRegularExpression.escapedPattern(for: loweredPattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: ".*")
        regexPattern = "^" + regexPattern + "$"
        return text.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
