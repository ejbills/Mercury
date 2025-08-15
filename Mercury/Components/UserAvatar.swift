//
//  UserAvatar.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

struct UserAvatar: View {
    let username: String
    let size: CGFloat
    let iconURL: URL?
    
    @Environment(\.redditAPI) private var redditAPI
    @State private var profileIconURL: URL?
    
    init(username: String, size: CGFloat = 32, iconURL: URL? = nil) {
        self.username = username
        self.size = size
        self.iconURL = iconURL
    }
    
    var body: some View {
        AsyncImage(url: displayURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_), .empty:
                fallbackAvatar
            @unknown default:
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task {
            if iconURL == nil && profileIconURL == nil {
                await loadUserIcon()
            }
        }
    }
    
    private var displayURL: URL? {
        return iconURL ?? profileIconURL ?? constructAvatarURL()
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
            
            Text(String(username.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    private func loadUserIcon() async {
        let cleanUsername = username.replacingOccurrences(of: "/u/", with: "")
            .replacingOccurrences(of: "u/", with: "")
        
        do {
            let profile = try await redditAPI.userService.fetchUserProfile(username: cleanUsername)
            await MainActor.run {
                self.profileIconURL = profile.profileIconURL
            }
        } catch {
            // Silently fail - will show fallback avatar
            print("Failed to load avatar for \(cleanUsername): \(error)")
        }
    }
    
    private func constructAvatarURL() -> URL? {
        // Clean username
        let cleanUsername = username.replacingOccurrences(of: "/u/", with: "")
            .replacingOccurrences(of: "u/", with: "")
        
        // Try Reddit's Snoovatar system with consistent hash-based selection
        let hash = abs(cleanUsername.hashValue) % 20
        return URL(string: "https://www.redditstatic.com/avatars/defaults/v2/avatar_default_\(hash).png")
    }
    
    private var avatarBackgroundColor: Color {
        // Generate consistent color based on username
        let hash = abs(username.hashValue)
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .cyan, 
            .mint, .yellow, .red, .indigo, .teal, .brown
        ]
        return colors[hash % colors.count]
    }
}

#Preview {
    VStack {
        UserAvatar(username: "testuser", size: 32)
        UserAvatar(username: "anotherguy", size: 48)
        UserAvatar(username: "coolperson", size: 64)
    }
    .padding()
}