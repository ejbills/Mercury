import Foundation

extension Notification.Name {
    // Posts
    static let hidePost = Notification.Name("Mercury.HidePost")
    static let hidePostsAbove = Notification.Name("Mercury.HidePostsAbove")

    // Comments
    static let collapseAncestorsToRoot = Notification.Name("Mercury.CollapseAncestorsToRoot")

    // Gestures: used to temporarily disable parent scrolling during swipe
    static let swipeInteractionBegan = Notification.Name("Mercury.SwipeInteractionBegan")
    static let swipeInteractionEnded = Notification.Name("Mercury.SwipeInteractionEnded")

}

enum AppNotificationKey {
    static let postId = "postId"
    static let commentId = "commentId"
}
