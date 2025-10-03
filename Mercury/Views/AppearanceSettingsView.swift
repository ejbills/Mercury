import SwiftUI
import Defaults

struct AppearanceSettingsView: View {
    // Posts
    @Default(.postLayoutStyle) private var postLayoutStyle
    // Normal
    @Default(.postNormalShowSubreddit) private var postNormalShowSubreddit
    @Default(.postNormalShowSubredditIcon) private var postNormalShowSubredditIcon
    @Default(.postNormalShowAuthor) private var postNormalShowAuthor
    @Default(.postNormalShowAvatar) private var postNormalShowAvatar
    @Default(.postNormalShowTime) private var postNormalShowTime
    @Default(.postNormalShowDomain) private var postNormalShowDomain
    @Default(.postNormalShowFlair) private var postNormalShowFlair
    @Default(.postNormalShowScore) private var postNormalShowScore
    @Default(.postNormalShowCommentCount) private var postNormalShowCommentCount
    @Default(.postNormalShowVoting) private var postNormalShowVoting
    @Default(.postNormalShowActions) private var postNormalShowActions
    // Compact
    @Default(.postCompactThumbnailSize) private var postCompactThumbSize
    @Default(.postCompactThumbnailPosition) private var postCompactThumbPosition
    @Default(.postCompactShowThumbnail) private var postCompactShowThumbnail
    @Default(.postCompactHideTextThumbnails) private var postCompactHideTextThumbs
    @Default(.postCompactShowSubreddit) private var postCompactShowSubreddit
    @Default(.postCompactShowSubredditIcon) private var postCompactShowSubredditIcon
    @Default(.postCompactShowAuthor) private var postCompactShowAuthor
    @Default(.postCompactShowAvatar) private var postCompactShowAvatar
    @Default(.postCompactShowTime) private var postCompactShowTime
    @Default(.postCompactShowDomain) private var postCompactShowDomain
    @Default(.postCompactShowFlair) private var postCompactShowFlair
    @Default(.postCompactShowScore) private var postCompactShowScore
    @Default(.postCompactShowCommentCount) private var postCompactShowCommentCount
    @Default(.postCompactShowVoting) private var postCompactShowVoting
    @Default(.postCompactShowActions) private var postCompactShowActions

    // Comments
    @Default(.commentLayoutStyle) private var commentLayoutStyle
    // Normal
    @Default(.commentNormalShowAuthor) private var commentNormalShowAuthor
    @Default(.commentNormalShowAvatar) private var commentNormalShowAvatar
    @Default(.commentNormalShowTime) private var commentNormalShowTime
    @Default(.commentNormalShowScore) private var commentNormalShowScore
    @Default(.commentNormalShowVoteButtons) private var commentNormalShowVoteButtons
    @Default(.commentNormalShowActions) private var commentNormalShowActions
    // Compact
    @Default(.commentCompactShowAuthor) private var commentCompactShowAuthor
    @Default(.commentCompactShowAvatar) private var commentCompactShowAvatar
    @Default(.commentCompactShowTime) private var commentCompactShowTime
    @Default(.commentCompactShowScore) private var commentCompactShowScore
    @Default(.commentCompactShowVoteButtons) private var commentCompactShowVoteButtons
    @Default(.commentCompactShowActions) private var commentCompactShowActions

    // Legacy bridging for old toggle
    @Default(.compactMode) private var legacyCompactMode

    // Preview state
    @Namespace private var previewNamespace
    @State private var previewSelectedPost: RedditPost? = nil
    @State private var showingResetConfirm = false
    // Disclosure state
    @State private var expandPostsNormal = false
    @State private var expandPostsCompact = false
    @State private var expandCommentsNormal = false
    @State private var expandCommentsCompact = false
    // Tuning group state (removed consolidated tuning groups)
    // Tuning
    @Default(.feedItemSpacing) private var feedItemSpacing
    @Default(.commentRowVerticalPadding) private var commentRowVerticalPadding
    @Default(.postNormalCardCornerRadius) private var postNormalCorner
    @Default(.postCompactCardCornerRadius) private var postCompactCorner
    @Default(.commentRootCardCornerRadius) private var commentRootCorner
    @Default(.commentChildCardCornerRadius) private var commentChildCorner

    var body: some View {
        List {
            // Post preview
            Section("Post Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if postLayoutStyle == .compact {
                            CompactPostRowView(
                                post: samplePost,
                                namespace: previewNamespace,
                                selectedPost: $previewSelectedPost
                            )
                            .allowsHitTesting(false)
                        } else {
                            PostRowView(
                                post: samplePost,
                                namespace: previewNamespace,
                                selectedPost: $previewSelectedPost,
                                showLargeToolbar: false,
                                showFullText: false
                            )
                            .allowsHitTesting(false)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }

            Section("Posts") {
                Picker("Layout", selection: $postLayoutStyle) {
                    ForEach(PostLayoutStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: postLayoutStyle) { _, newValue in
                    // Bridge to legacy compactMode for older code paths
                    legacyCompactMode = (newValue == .compact)
                }

                DisclosureGroup(isExpanded: $expandPostsNormal) {
                    Toggle("Show Subreddit", isOn: $postNormalShowSubreddit)
                    Toggle("Show Subreddit Icon", isOn: $postNormalShowSubredditIcon)
                    Toggle("Show Author", isOn: $postNormalShowAuthor)
                    Toggle("Show Author Avatar", isOn: $postNormalShowAvatar)
                    Toggle("Show Time", isOn: $postNormalShowTime)
                    Toggle("Show Domain (Links)", isOn: $postNormalShowDomain)
                    Toggle("Show Flair", isOn: $postNormalShowFlair)
                    Toggle("Show Score", isOn: $postNormalShowScore)
                    Toggle("Show Comment Count", isOn: $postNormalShowCommentCount)
                    Toggle("Show Upvote/Downvote Buttons", isOn: $postNormalShowVoting)
                    Toggle("Show Action Bar", isOn: $postNormalShowActions)
                    TuningSliderRow(
                        title: "Card Corner Radius",
                        value: $postNormalCorner,
                        range: 0...30,
                        step: 1
                    )
                } label: {
                    Label("Normal Options", systemImage: "rectangle.grid.1x2")
                }

                DisclosureGroup(isExpanded: $expandPostsCompact) {
                    Picker("Thumbnail Position", selection: $postCompactThumbPosition) {
                        ForEach(ThumbnailPosition.allCases, id: \.self) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Thumbnail Size", selection: $postCompactThumbSize) {
                        ForEach(ThumbnailSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Show Thumbnails", isOn: $postCompactShowThumbnail)
                    Toggle("Hide Thumbnails For Text Posts", isOn: $postCompactHideTextThumbs)
                    Toggle("Show Subreddit", isOn: $postCompactShowSubreddit)
                    Toggle("Show Subreddit Icon", isOn: $postCompactShowSubredditIcon)
                    Toggle("Show Author", isOn: $postCompactShowAuthor)
                    Toggle("Show Author Avatar", isOn: $postCompactShowAvatar)
                    Toggle("Show Time", isOn: $postCompactShowTime)
                    Toggle("Show Domain (Links)", isOn: $postCompactShowDomain)
                    Toggle("Show Flair", isOn: $postCompactShowFlair)
                    Toggle("Show Score", isOn: $postCompactShowScore)
                    Toggle("Show Comment Count", isOn: $postCompactShowCommentCount)
                    Toggle("Show Upvote/Downvote Buttons", isOn: $postCompactShowVoting)
                    Toggle("Show Action Bar", isOn: $postCompactShowActions)
                    TuningSliderRow(
                        title: "Card Corner Radius",
                        value: $postCompactCorner,
                        range: 0...30,
                        step: 1
                    )
                } label: {
                    Label("Compact Options", systemImage: "square.grid.3x2")
                }
            }

            // Comment preview
            Section("Comment Preview") {
                Group {
                    if commentLayoutStyle == .compact {
                        CompactCommentView(
                            comment: sampleComment(),
                            depth: 0,
                            post: samplePost,
                            isCollapsed: false
                        )
                        .allowsHitTesting(false)
                    } else {
                        CommentView(
                            comment: sampleComment(),
                            depth: 0,
                            post: samplePost,
                            isCollapsed: false,
                            onCollapseToggle: {},
                            onCollapseParent: {},
                            onScrollToParent: {},
                            onReplyPosted: { _ in }
                        )
                        .allowsHitTesting(false)
                    }
                }
            }

            Section("Comments") {
                Picker("Layout", selection: $commentLayoutStyle) {
                    ForEach(CommentLayoutStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                DisclosureGroup(isExpanded: $expandCommentsNormal) {
                    Toggle("Show Author", isOn: $commentNormalShowAuthor)
                    Toggle("Show Author Avatar", isOn: $commentNormalShowAvatar)
                    Toggle("Show Time", isOn: $commentNormalShowTime)
                    Toggle("Show Score", isOn: $commentNormalShowScore)
                    Toggle("Show Upvote/Downvote Buttons", isOn: $commentNormalShowVoteButtons)
                    Toggle("Show Action Buttons", isOn: $commentNormalShowActions)
                    TuningSliderRow(
                        title: "Root Card Corner",
                        value: $commentRootCorner,
                        range: 0...30,
                        step: 1
                    )
                    TuningSliderRow(
                        title: "Child Card Corner",
                        value: $commentChildCorner,
                        range: 0...30,
                        step: 1
                    )
                } label: {
                    Label("Normal Options", systemImage: "text.bubble")
                }

                DisclosureGroup(isExpanded: $expandCommentsCompact) {
                    Toggle("Show Author", isOn: $commentCompactShowAuthor)
                    Toggle("Show Author Avatar", isOn: $commentCompactShowAvatar)
                    Toggle("Show Time", isOn: $commentCompactShowTime)
                    Toggle("Show Score", isOn: $commentCompactShowScore)
                    Toggle("Show Upvote/Downvote Buttons", isOn: $commentCompactShowVoteButtons)
                    Toggle("Show Action Buttons", isOn: $commentCompactShowActions)
                    TuningSliderRow(
                        title: "Root Card Corner",
                        value: $commentRootCorner,
                        range: 0...30,
                        step: 1
                    )
                    TuningSliderRow(
                        title: "Child Card Corner",
                        value: $commentChildCorner,
                        range: 0...30,
                        step: 1
                    )
                } label: {
                    Label("Compact Options", systemImage: "text.bubble.fill")
                }
            }

            // Spacing controls
            Section("Spacing") {
                TuningSliderRow(
                    title: "Post Spacing",
                    value: $feedItemSpacing,
                    range: 0...24,
                    step: 1
                )
                TuningSliderRow(
                    title: "Comment Spacing",
                    value: $commentRowVerticalPadding,
                    range: 0...12,
                    step: 1
                )
            }

            // Reset
            Section {
                Button {
                    showingResetConfirm = true
                } label: {
                    Label("Reset Appearance to Defaults", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Resets post and comment appearance options to their default values.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .onAppear {
            // Initialize from legacy compact toggle if user had set it
            if legacyCompactMode, postLayoutStyle == .normal {
                postLayoutStyle = .compact
            }
        }
        .alert("Reset Appearance?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset") { resetAppearance() }
        } message: {
            Text("This will restore all appearance settings for posts and comments.")
        }
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}

// MARK: - Reusable rows

private struct TuningSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value)) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Local sample data

private extension AppearanceSettingsView {
    var samplePost: RedditPost { RedditPost.samplePost }

    func sampleComment() -> RedditComment {
        let json = """
        {
          "id": "c_placeholder",
          "subreddit": "apple",
          "author": "sample_user",
          "body": "This is a sample comment used for previewing appearance settings.",
          "score": 1234,
          "depth": 0,
          "created_utc": 1600000000,
          "permalink": "/r/apple/comments/xxxxxx/sample_post_title/c_placeholder/",
          "is_submitter": false,
          "score_hidden": false,
          "stickied": false,
          "saved": false,
          "archived": false,
          "locked": false,
          "replies": ""
        }
        """
        let decoder = JSONDecoder()
        if let data = json.data(using: .utf8), let comment = try? decoder.decode(RedditComment.self, from: data) {
            return comment
        }
        // Fallback minimal
        let fallback = """
        { "id":"c_fallback", "author":"user", "body":"Sample", "permalink":"/r/test/comments/a/b/" }
        """
        let data = fallback.data(using: .utf8)!
        return (try? decoder.decode(RedditComment.self, from: data)) ?? {
            // As a last resort, decode a safe minimal JSON
            let minimal = "{\"id\":\"c_min\",\"author\":\"user\",\"body\":\"Sample\",\"permalink\":\"/r/test/comments/a/b/\"}"
            return try! decoder.decode(RedditComment.self, from: minimal.data(using: .utf8)!)
        }()
    }

    func resetAppearance() {
        // Posts
        Defaults[.postLayoutStyle] = .normal
        // Normal
        Defaults[.postNormalShowSubreddit] = true
        Defaults[.postNormalShowSubredditIcon] = true
        Defaults[.postNormalShowAuthor] = true
        Defaults[.postNormalShowAvatar] = true
        Defaults[.postNormalShowTime] = true
        Defaults[.postNormalShowDomain] = true
        Defaults[.postNormalShowFlair] = true
        Defaults[.postNormalShowScore] = true
        Defaults[.postNormalShowCommentCount] = true
        Defaults[.postNormalShowVoting] = true
        Defaults[.postNormalShowActions] = true
        // Compact
        Defaults[.postCompactThumbnailSize] = .medium
        Defaults[.postCompactShowThumbnail] = true
        Defaults[.postCompactHideTextThumbnails] = false
        Defaults[.postCompactShowSubredditIcon] = true
        Defaults[.postCompactThumbnailPosition] = .right
        Defaults[.postCompactShowSubreddit] = true
        Defaults[.postCompactShowAuthor] = true
        Defaults[.postCompactShowAvatar] = true
        Defaults[.postCompactShowTime] = true
        Defaults[.postCompactShowDomain] = true
        Defaults[.postCompactShowFlair] = true
        Defaults[.postCompactShowScore] = true
        Defaults[.postCompactShowCommentCount] = true
        Defaults[.postCompactShowVoting] = true
        Defaults[.postCompactShowActions] = true

        // Comments
        Defaults[.commentLayoutStyle] = .normal
        // Normal
        Defaults[.commentNormalShowAuthor] = true
        Defaults[.commentNormalShowAvatar] = true
        Defaults[.commentNormalShowTime] = true
        Defaults[.commentNormalShowScore] = true
        Defaults[.commentNormalShowVoteButtons] = true
        Defaults[.commentNormalShowActions] = true
        // Compact
        Defaults[.commentCompactShowAuthor] = true
        Defaults[.commentCompactShowAvatar] = true
        Defaults[.commentCompactShowTime] = true
        Defaults[.commentCompactShowScore] = true
        Defaults[.commentCompactShowVoteButtons] = true
        Defaults[.commentCompactShowActions] = true

        // Legacy bridge
        Defaults[.compactMode] = false

        // Tuning defaults
        Defaults[.feedItemSpacing] = 8
        Defaults[.commentRowVerticalPadding] = 4
        Defaults[.postNormalCardCornerRadius] = 16
        Defaults[.postCompactCardCornerRadius] = 8
        Defaults[.commentRootCardCornerRadius] = 16
        Defaults[.commentChildCardCornerRadius] = 12
    }
}
