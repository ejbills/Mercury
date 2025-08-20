//
//  UserProfileView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import NukeUI

struct UserProfileView: View {
    let username: String
    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.navigationPathManager) private var navigationPath
    
    @State private var userProfile: UserProfile?
    @State private var userPosts: [RedditPost] = []
    @State private var isLoading = true
    @State private var isLoadingPosts = false
    @State private var errorMessage: String?
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var mediaNamespace
    @State private var selectedPost: RedditPost?
    @State private var videoHandoffState: VideoHandoffState?
    @State private var selectedSection: ProfileSection = .posts
    
    enum ProfileSection: String, CaseIterable {
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
    
    // Generate consistent color for user based on username
    private var userColor: Color {
        let hash = username.hashValue
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple, .pink, .cyan, .mint, .teal]
        return colors[abs(hash) % colors.count]
    }
    
    private var profileImageView: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: 120, height: 120)
            
            Circle()
                .fill(userColor.gradient)
                .frame(width: 110, height: 110)
            
            // Try to load profile image if available
            if let profile = userProfile, let iconUrl = profile.effectiveIconImg, !iconUrl.isEmpty {
                LazyImage(url: URL(string: iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    } else {
                        // Fallback to initial
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                // Default initial
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header with gradient background
                    headerSection
                        .frame(height: 320)
                    
                    // Action buttons
                    actionButtonsSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    
                    // Content sections
                    contentSections
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
        .task {
            await loadUserProfile()
        }
    }
    
    private var headerSection: some View {
        ZStack {
            // User-specific gradient background
            LinearGradient(
                colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                
                // Profile image - large circular design like iOS Contacts
                profileImageView
                
                // User info
                VStack(spacing: 8) {
                    Text("u/\(username)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    if let profile = userProfile {
                        Text("\(profile.totalKarma.formatted()) karma")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        if let created = profile.created {
                            let createdDate = Date(timeIntervalSince1970: created)
                            Text("Redditor since \(createdDate.formatted(.dateTime.year().month(.wide)))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            actionButton(icon: "message.fill", title: "Message", color: .blue) {
                // Handle message action
            }
            
            actionButton(icon: "person.badge.plus.fill", title: "Follow", color: .green) {
                // Handle follow action
            }
            
            actionButton(icon: "square.and.arrow.up.fill", title: "Share", color: .orange) {
                handleShare()
            }
            
            actionButton(icon: "ellipsis", title: "More", color: .gray) {
                // Handle more actions
            }
        }
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(color.gradient, in: Circle())
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var contentSections: some View {
        VStack(spacing: 0) {
            // Section picker
            sectionPicker
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            
            // Content based on selected section
            switch selectedSection {
            case .posts:
                postsSection
            case .comments:
                commentsSection
            case .about:
                aboutSection
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }
    
    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ProfileSection.allCases, id: \.self) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedSection = section
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(section.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(selectedSection == section ? .white : .primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        if selectedSection == section {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.blue.gradient)
                                .matchedGeometryEffect(id: "selectedSection", in: mediaNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var postsSection: some View {
        if isLoading && userPosts.isEmpty {
            profileLoadingView
        } else if let errorMessage = errorMessage {
            profileErrorView(errorMessage)
        } else if userPosts.isEmpty {
            profileEmptyStateView
        } else {
            LazyVStack(spacing: 12) {
                ForEach(userPosts) { post in
                    PostRowView(
                        post: post, 
                        namespace: mediaNamespace, 
                        selectedPost: $selectedPost,
                        onVideoHandoff: { handoffState in
                            videoHandoffState = handoffState
                        }
                    )
                        .onAppear {
                            if post.id == userPosts.last?.id && hasMore && !isLoadingPosts {
                                Task {
                                    await loadMorePosts()
                                }
                            }
                        }
                }
                
                if hasMore && !userPosts.isEmpty {
                    loadMoreSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private var commentsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Comments Coming Soon")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("User comments will be displayed here in a future update.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        if let profile = userProfile {
            VStack(alignment: .leading, spacing: 20) {
                profileInfoCard("Account Info", icon: "person.circle") {
                    profileInfoRow("Username", value: "u/\(username)")
                    profileInfoRow("Total Karma", value: profile.totalKarma.formatted())
                    profileInfoRow("Link Karma", value: (profile.linkKarma ?? 0).formatted())
                    profileInfoRow("Comment Karma", value: (profile.commentKarma ?? 0).formatted())
                    
                    if let created = profile.created {
                        let createdDate = Date(timeIntervalSince1970: created)
                        profileInfoRow("Cake Day", value: createdDate.formatted(.dateTime.year().month(.wide).day()))
                    }
                }
                
                profileInfoCard("Account Status", icon: "checkmark.shield") {
                    profileInfoRow("Verified", value: (profile.verified ?? false) ? "Yes" : "No")
                    profileInfoRow("Email Verified", value: (profile.hasVerifiedEmail ?? false) ? "Yes" : "No")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        } else {
            profileLoadingView
        }
    }
    
    private func profileInfoCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func profileInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var profileLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func profileErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load profile")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadUserProfile()
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
    }
    
    private var profileEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Posts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This user hasn't posted anything yet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var loadMoreSection: some View {
        Group {
            if isLoadingPosts {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading more posts...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        if hasMore && !isLoadingPosts {
                            Task {
                                await loadMorePosts()
                            }
                        }
                    }
            }
        }
    }
    
    private func loadUserProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let profileTask = redditAPI.fetchUserProfile(username: username)
            async let postsTask = redditAPI.fetchUserPosts(username: username, after: nil, limit: 25)
            
            let (profile, postsResponse) = try await (profileTask, postsTask)
            
            await MainActor.run {
                self.userProfile = profile
                self.userPosts = postsResponse.data.children.compactMap { $0.data }
                self.after = postsResponse.data.after
                self.hasMore = postsResponse.data.after != nil && !self.userPosts.isEmpty
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadMorePosts() async {
        guard hasMore && !isLoadingPosts && after != nil else { return }
        
        await MainActor.run {
            isLoadingPosts = true
        }
        
        do {
            let response = try await redditAPI.fetchUserPosts(username: username, after: after, limit: 25)
            await MainActor.run {
                let newPosts = response.data.children.compactMap { $0.data }
                
                let uniqueNewPosts = newPosts.filter { newPost in
                    !userPosts.contains { existingPost in
                        existingPost.id == newPost.id
                    }
                }
                
                self.userPosts.append(contentsOf: uniqueNewPosts)
                self.after = response.data.after
                self.hasMore = response.data.after != nil && !newPosts.isEmpty
                self.isLoadingPosts = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingPosts = false
            }
        }
    }
    
    private func handleShare() {
        let profileURL = "https://reddit.com/u/\(username)"
        let activityVC = UIActivityViewController(
            activityItems: [profileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(username: "testuser")
            .environment(\.redditAPI, RedditAPIManager())
    }
}