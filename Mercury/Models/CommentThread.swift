import Foundation

struct CommentThread: Identifiable {
    let id = UUID()
    let parentComment: RedditComment
    init(parentComment: RedditComment) {
        self.parentComment = parentComment
    }
}

/// Represents a comment thread item that can be either a comment or a "more" object
enum CommentThreadItem: Identifiable {
    case comment(RedditComment)
    case more(MoreComments)
    
    var id: String {
        switch self {
        case .comment(let comment):
            return comment.id
        case .more(let more):
            return more.id
        }
    }
    
    var depth: Int {
        switch self {
        case .comment(let comment):
            return comment.depth
        case .more(let more):
            return more.depth
        }
    }
}

@Observable
class CommentThreadManager {
    private(set) var commentThreads: [CommentThread] = []
    private(set) var moreObjects: [MoreComments] = []
    private var allComments: [RedditComment] = []
    private(set) var rootAfter: String? = nil
    var hasMoreRootComments: Bool { rootAfter != nil }
    private var rootRemainingChildren: [String] = []
    
    func loadInitialComments(_ comments: [RedditComment], moreObjects: [MoreComments], rootAfter: String?) {
        self.allComments = comments
        self.rootAfter = rootAfter
        self.rootRemainingChildren = []
        
        if shouldAddRootLevelLoadMore(comments: comments) {
            let afterToken = rootAfter ?? ""
            let rootLoadMore = MoreComments(
                count: 25,
                name: "root_pagination",
                rawId: "root_pagination",
                parentId: nil,
                depth: 0,
                children: afterToken.isEmpty ? [] : [afterToken]
            )
            self.moreObjects = [rootLoadMore]
        } else {
            let rootMores = moreObjects.filter { $0.depth == 0 }
            if !rootMores.isEmpty {
                let combinedChildren = rootMores.flatMap { $0.children }
                self.rootRemainingChildren = combinedChildren
                let slice = Array(combinedChildren.prefix(25))
                if !slice.isEmpty {
                    let consolidated = MoreComments(
                        count: slice.count,
                        name: "root_more_children",
                        rawId: "root_more_children",
                        parentId: nil,
                        depth: 0,
                        children: slice
                    )
                    self.moreObjects = [consolidated]
                } else {
                    self.moreObjects = []
                }
            } else {
                self.moreObjects = []
            }
        }
        commentThreads = buildCommentThreads(from: comments)
    }
    
    func appendRootPage(newComments: [RedditComment], nextAfter: String?) {
        allComments.append(contentsOf: newComments)
        rootAfter = nextAfter
        let newThreads = newComments.filter { $0.depth == 0 }.map { CommentThread(parentComment: $0) }
        commentThreads.append(contentsOf: newThreads)
        if let after = nextAfter {
            moreObjects = [
                MoreComments(
                    count: 25,
                    name: "root_pagination",
                    rawId: "root_pagination",
                    parentId: nil,
                    depth: 0,
                    children: [after]
                )
            ]
        } else {
            moreObjects = []
        }
    }

    func appendRootChildrenPage(newComments: [RedditComment], consumedCount: Int) {
        allComments.append(contentsOf: newComments)
        let newThreads = newComments.filter { $0.depth == 0 }.map { CommentThread(parentComment: $0) }
        commentThreads.append(contentsOf: newThreads)
        if consumedCount > 0 && consumedCount <= rootRemainingChildren.count {
            rootRemainingChildren.removeFirst(consumedCount)
        }
        if rootRemainingChildren.isEmpty {
            moreObjects = []
        } else {
            let nextSlice = Array(rootRemainingChildren.prefix(25))
            let consolidated = MoreComments(
                count: nextSlice.count,
                name: "root_more_children",
                rawId: "root_more_children",
                parentId: nil,
                depth: 0,
                children: nextSlice
            )
            moreObjects = [consolidated]
        }
    }

    private func shouldAddRootLevelLoadMore(comments: [RedditComment]) -> Bool {
        return rootAfter != nil && !comments.filter { $0.depth == 0 }.isEmpty
    }
    
    private func buildCommentThreads(from comments: [RedditComment]) -> [CommentThread] {
        let topLevelComments = comments.filter { $0.depth == 0 }
        let threads = topLevelComments.map { topComment in
            CommentThread(parentComment: topComment)
        }
        return threads
    }
    
    func insertMoreComments(_ newComments: [RedditComment], replacingMoreId: String) {
        moreObjects.removeAll { $0.id == replacingMoreId }
        let newTopLevelComments = newComments.filter { $0.depth == 0 }
        let newThreads = newTopLevelComments.map { CommentThread(parentComment: $0) }
        commentThreads.append(contentsOf: newThreads)
    }

}

extension CommentThreadManager {
    func addRootComment(_ comment: RedditComment) {
        let newComment = comment // value copy for clarity
        allComments.insert(newComment, at: 0)
        commentThreads.insert(CommentThread(parentComment: newComment), at: 0)
    }
}
