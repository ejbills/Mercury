import SwiftUI

struct UserAvatar: View {
    let username: String
    let size: CGFloat
    let iconURL: URL?
    
    init(username: String, size: CGFloat = 32, iconURL: URL? = nil) {
        self.username = username
        self.size = size
        self.iconURL = iconURL
    }
    
    var body: some View {
        Group {
            if isDeletedUser {
                deletedUserAvatar
            } else if let iconURL = iconURL {
                AsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallbackAvatar
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
            
            Text(firstLetter)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    private var deletedUserAvatar: some View {
        ZStack {
            Circle()
                .fill(.red.opacity(0.2))
            
            Image(systemName: "trash")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(.red)
        }
    }
    
    private var isDeletedUser: Bool {
        username == "[deleted]" || username == "deleted"
    }
    
    private var firstLetter: String {
        String(username.prefix(1)).uppercased()
    }
    
    private var avatarBackgroundColor: Color {
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
        UserAvatar(username: "[deleted]", size: 32)
    }
    .padding()
}