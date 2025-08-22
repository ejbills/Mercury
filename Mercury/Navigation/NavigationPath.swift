import SwiftUI

// MARK: - Navigation Destinations
enum NavigationDestination: Hashable {
    case subredditFeed(subreddit: String)
    case userProfile(username: String)
    case postDetail(post: RedditPost)
    case postComments(post: RedditPost)
    case postCommentsAnchor(post: RedditPost, commentId: String?)
}

// MARK: - Navigation Path Manager
@Observable
class NavigationPathManager {
    var path = NavigationPath()
    
    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }
    
    func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}

// MARK: - Environment Key
private struct NavigationPathManagerKey: EnvironmentKey {
    static let defaultValue = NavigationPathManager()
}

extension EnvironmentValues {
    var navigationPathManager: NavigationPathManager {
        get { self[NavigationPathManagerKey.self] }
        set { self[NavigationPathManagerKey.self] = newValue }
    }
}
