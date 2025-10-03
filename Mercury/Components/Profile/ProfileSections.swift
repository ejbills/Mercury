import SwiftUI
import Defaults

struct ProfilePostsSection: View {
    let posts: [RedditPost]
    let postsAfter: String?
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let mediaNamespace: Namespace.ID
    @Binding var selectedPost: RedditPost?
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    @Default(.feedItemSpacing) private var feedItemSpacing
    
    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProfileLoadingState(text: "Loading posts…")
            } else if let errorMessage, posts.isEmpty {
                ProfileErrorState(message: errorMessage, retry: { Task { await onRefresh() } })
            } else if posts.isEmpty {
                ProfileEmptyState(title: "No Posts", message: "This user hasn't posted yet.")
            } else {
                LazyVStack(spacing: CGFloat(feedItemSpacing)) {
                    ForEach(posts) { post in
                        if Defaults[.postLayoutStyle] == .compact {
                            CompactPostRowView(post: post, namespace: mediaNamespace, selectedPost: $selectedPost)
                        } else {
                            PostRowView(
                                post: post, 
                                namespace: mediaNamespace, 
                                selectedPost: $selectedPost
                            )
                        }
                    }
                }
                if postsAfter != nil {
                    HStack {
                        Spacer(minLength: 0)
                        Pill(action: { Task { await onLoadMore() } }) {
                            HStack(spacing: 8) {
                                if isLoadingMore { ProgressView().controlSize(.small) }
                                Image(systemName: "arrow.down.circle")
                                    .font(.headline)
                                Text(isLoadingMore ? "Loading more posts…" : "Load more posts")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isLoadingMore)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
        .padding(.top, 12)
    }
}

struct ProfileCommentsSection: View {
    let comments: [RedditComment]
    let commentsAfter: String?
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let commentsContextReady: Bool
    let commentPostMap: [String: RedditPost]
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let onCommentTap: (RedditPost) -> Void
    
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    var body: some View {
        Group {
            if isLoading && comments.isEmpty {
                ProfileLoadingState(text: "Loading comments…")
            } else if let errorMessage, comments.isEmpty {
                ProfileErrorState(message: errorMessage, retry: { Task { await onRefresh() } })
            } else if comments.isEmpty {
                ProfileEmptyState(title: "No Comments", message: "This user hasn't commented yet.")
            } else if !commentsContextReady {
                ProfileLoadingState(text: "Preparing comments…")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(comments, id: \.self) { comment in
                        if let key = linkKey(for: comment), let post = commentPostMap[key] {
                            CommentView(comment: comment, depth: 0, post: post) { } onReplyPosted: { _ in }
                                .allowsHitTesting(false)
                                .environment(\.redditAPI, redditAPI)
                                .environment(\.navigationPathManager, navigationPath)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onCommentTap(post)
                                }
                        }
                    }
                }
                if commentsAfter != nil {
                    HStack {
                        Spacer(minLength: 0)
                        Pill(action: { Task { await onLoadMore() } }) {
                            HStack(spacing: 8) {
                                if isLoadingMore { ProgressView().controlSize(.small) }
                                Image(systemName: "arrow.down.circle")
                                    .font(.headline)
                                Text(isLoadingMore ? "Loading more comments…" : "Load more comments")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isLoadingMore)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
        .padding(.top, 12)
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

struct ProfileAboutSection: View {
    let profile: UserProfile?
    let username: String
    
    var body: some View {
        Group {
            if let profile {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("About")
                    infoRow(label: "Username", value: "u/\(profile.actualName)")
                    infoRow(label: "Total Karma", value: profile.totalKarma.formatted())
                    infoRow(label: "Link Karma", value: (profile.linkKarma ?? 0).formatted())
                    infoRow(label: "Comment Karma", value: (profile.commentKarma ?? 0).formatted())
                    if let created = profile.created { 
                        infoRow(label: "Cake Day", value: cakeDayText(created)) 
                    }
                    infoRow(label: "Verified", value: (profile.verified ?? false) ? "Yes" : "No")
                    infoRow(label: "Email Verified", value: (profile.hasVerifiedEmail ?? false) ? "Yes" : "No")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            } else {
                ProfileLoadingState(text: "Loading profile…")
            }
        }
        .padding(.top, 12)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
        .overlay(
            Divider()
                .opacity(0.6)
                .offset(y: 18),
            alignment: .bottom
        )
    }
    
    private func cakeDayText(_ createdUTC: Double) -> String {
        let date = Date(timeIntervalSince1970: createdUTC)
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

// MARK: - Shared State Views

struct ProfileLoadingState: View {
    let text: String
    
    private var accentColor: Color {
        let colors: [Color] = [.orange, .pink, .purple, .blue, .teal, .mint, .indigo]
        return colors[abs(text.hashValue) % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(accentColor)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

struct ProfileEmptyState: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.quaternary)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
    }
}

struct ProfileErrorState: View {
    let message: String
    let retry: () -> Void
    
    private var accentColor: Color {
        let colors: [Color] = [.orange, .pink, .purple, .blue, .teal, .mint, .indigo]
        return colors[abs(message.hashValue) % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("Failed to load")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: retry) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
    }
}
