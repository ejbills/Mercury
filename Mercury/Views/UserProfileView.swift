//
//  UserProfileView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI

struct UserProfileView: View {
    let username: String
    @Environment(\.redditAPI) private var redditAPI
    
    @State private var userProfile: UserProfile?
    @State private var userPosts: [RedditPost] = []
    @State private var isLoading = true
    @State private var isLoadingPosts = false
    @State private var errorMessage: String?
    @State private var after: String?
    @State private var hasMore = true
    @Namespace private var mediaNamespace
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            profileLoadingView
                        } else if let errorMessage = errorMessage {
                            errorView(errorMessage)
                        } else if let profile = userProfile {
                            profileHeaderView(profile)
                                .padding(.bottom, 24)
                            
                            if userPosts.isEmpty && !isLoadingPosts {
                                emptyPostsView
                            } else {
                                postsSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("u/\(username)")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadUserProfile()
            }
            .task {
                await loadUserProfile()
            }
        }
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
        .padding(.top, 100)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
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
        .padding(.top, 100)
    }
    
    private func profileHeaderView(_ profile: UserProfile) -> some View {
        VStack(spacing: 20) {
            // Profile Picture and Name - Following Apple's Contact/Profile design patterns
            VStack(spacing: 12) {
                profileImage(profile)
                
                VStack(spacing: 4) {
                    Text("u/\(profile.name)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 12) {
                        if profile.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .accessibilityLabel("Verified user")
                        }
                        
                        if profile.isPremium == true {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .accessibilityLabel("Premium member")
                        }
                        
                        if profile.isEmployee == true {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Reddit employee")
                        }
                    }
                }
            }
            
            // Stats using Apple's standard grouped style
            GroupBox {
                HStack(spacing: 0) {
                    statItem("Post Karma", value: profile.linkKarma.formatted())
                    
                    Divider()
                        .frame(height: 44)
                        .foregroundStyle(.separator)
                    
                    statItem("Comment Karma", value: profile.commentKarma.formatted())
                    
                    Divider()
                        .frame(height: 44)
                        .foregroundStyle(.separator)
                    
                    statItem("Cake Day", value: profile.accountAge)
                }
                .padding(.vertical, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Profile Description using Apple's standard text styling
            if let subreddit = profile.subreddit,
               let description = subreddit.publicDescription,
               !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func profileImage(_ profile: UserProfile) -> some View {
        Group {
            if let profileIconURL = profile.profileIconURL {
                LazyImage(url: profileIconURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        profileImagePlaceholder(profile.name)
                    }
                }
            } else {
                profileImagePlaceholder(profile.name)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func profileImagePlaceholder(_ username: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.gradient)
            
            Text(String(username.prefix(1)).uppercased())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
    
    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyPostsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
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
        .padding(.vertical, 40)
    }
    
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Posts")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(userPosts) { post in
                    PostRowView(post: post, namespace: mediaNamespace)
                        .onAppear {
                            if post.id == userPosts.last?.id && hasMore && !isLoadingPosts {
                                Task {
                                    await loadMorePosts()
                                }
                            }
                        }
                }
                
                if hasMore && !userPosts.isEmpty {
                    HStack(spacing: 8) {
                        if isLoadingPosts {
                            ProgressView()
                                .controlSize(.regular)
                            Text("Loading more posts...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadUserProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            userProfile = nil
            userPosts = []
            after = nil
            hasMore = true
        }
        
        do {
            async let profileTask = redditAPI.fetchUserProfile(username: username)
            async let postsTask = redditAPI.fetchUserPosts(username: username, limit: 25)
            
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
}

#Preview {
    UserProfileView(username: "spez")
}
