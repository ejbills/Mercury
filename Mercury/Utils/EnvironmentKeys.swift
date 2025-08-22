import SwiftUI

private struct RedditAPIKey: EnvironmentKey {
    static let defaultValue: RedditAPIManager = RedditAPIManager()
}

extension EnvironmentValues {
    var redditAPI: RedditAPIManager {
        get { self[RedditAPIKey.self] }
        set { self[RedditAPIKey.self] = newValue }
    }
}

