import SwiftUI

struct UserProfileView: View {
    let username: String
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    @State private var viewModel: ProfileViewModel
    @Namespace private var mediaNamespace
    @State private var selectedPost: RedditPost?
    @State private var showCompose = false
    @State private var videoHandoffState: VideoHandoffState?
    @State private var selectedSection: ProfileSection = .posts
    @State private var showProfileWeb = false
    @State private var showingCopiedToast = false
    @State private var shareItem: ShareItem?
    @Namespace private var sectionNamespace
    @State private var hasBoundAPI = false
    
    init(username: String) {
        self.username = username
        self._viewModel = State(initialValue: ProfileViewModel(username: username, redditAPI: RedditAPIManager()))
    }
    
    enum ProfileSection: String, CaseIterable, SectionPickerIconProvider {
        case posts = "Posts"
        case comments = "Comments"
        case about = "About"
        
        var icon: String {
            switch self {
            case .posts: return "doc.text.fill"
            case .comments: return "bubble.left.fill"
            case .about: return "person.fill"
            }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    UserProfileHeader(
                        username: username,
                        profile: viewModel.profile,
                        headerAvatarURL: viewModel.headerAvatarURL,
                        isLoading: viewModel.isLoading,
                        onMessageTap: { showCompose = true },
                        onShareTap: shareProfile,
                        onOpenWebTap: { showProfileWeb = true },
                        onCopyTap: copyUsername,
                        isFollowing: viewModel.isFollowingUser,
                        onFollowToggle: { Task { await viewModel.toggleFollowUser() } }
                    )
                    
                    sectionPicker
                    
                    switch selectedSection {
                    case .posts:
                        ProfilePostsSection(
                            posts: viewModel.posts,
                            postsAfter: viewModel.postsAfter,
                            isLoading: viewModel.isLoading,
                            isLoadingMore: viewModel.isLoadingMorePosts,
                            errorMessage: viewModel.errorMessage,
                            mediaNamespace: mediaNamespace,
                            selectedPost: $selectedPost,
                            onRefresh: { await viewModel.refreshAll() },
                            onLoadMore: { await viewModel.loadMorePosts() }
                        )
                    case .comments:
                        ProfileCommentsSection(
                            comments: viewModel.comments,
                            commentsAfter: viewModel.commentsAfter,
                            isLoading: viewModel.isLoading,
                            isLoadingMore: viewModel.isLoadingMoreComments,
                            errorMessage: viewModel.errorMessage,
                            commentsContextReady: viewModel.commentsContextReady,
                            commentPostMap: viewModel.commentPostMap,
                            onRefresh: { await viewModel.refreshAll() },
                            onLoadMore: { await viewModel.loadMoreComments() },
                            onCommentTap: { post in
                                navigationPath.navigate(to: .postComments(post: post))
                            }
                        )
                    case .about:
                        ProfileAboutSection(
                            profile: viewModel.profile,
                            username: username
                        )
                    }
                }
            }
            .refreshable { await viewModel.refreshAll() }
        }
        .task {
            if !hasBoundAPI {
                viewModel = ProfileViewModel(username: username, redditAPI: redditAPI)
                hasBoundAPI = true
                await viewModel.initialLoad()
            }
        }
        .fullScreenCover(item: $selectedPost) { post in
            MediaDetailView(
                post: post,
                namespace: mediaNamespace,
                videoHandoffState: videoHandoffState,
                onVideoHandoffReturn: { returnedState in
                    videoHandoffState = returnedState
                    selectedPost = nil
                }
            )
        }
        .sheet(isPresented: $showCompose) {
            ComposeMessageSheet(toUsername: username, isPresented: $showCompose)
                .environment(\.redditAPI, redditAPI)
        }
        .sheet(isPresented: $showProfileWeb) {
            SafariView(url: profileURL)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(shareItem: item)
        }
        .overlay(alignment: .top) {
            CopiedToast(isShowing: showingCopiedToast)
        }
        .animation(.easeInOut(duration: 0.2), value: showingCopiedToast)
    }
    
    // MARK: - Sections
    
    private var sectionPicker: some View {
        SectionPicker(
            items: ProfileSection.allCases,
            selectedItem: $selectedSection,
            namespace: sectionNamespace,
            accentColor: .accentColor,
            onSelectionChanged: nil,
            useBackground: true,
            style: .glass
        )
    }
    // MARK: - Actions
    private func shareProfile() {
        let profileURL = URL(string: "https://reddit.com/u/\(username)")!
        shareItem = ShareItem(items: [profileURL])
    }
    
    private var profileURL: URL { URL(string: "https://reddit.com/u/\(username)")! }
    
    private func copyUsername() {
        UIPasteboard.general.string = "u/\(username)"
        showingCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showingCopiedToast = false }
        }
    }
}
