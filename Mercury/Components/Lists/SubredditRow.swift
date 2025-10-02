import SwiftUI
import Nuke
import NukeUI

struct SubredditRow: View {
    let subreddit: Subreddit
    let action: () -> Void
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let isSubscribed: Bool?
    let onSubscribeToggle: (() -> Void)?
    @State private var showUnsubscribeConfirm: Bool = false
    
    init(
        subreddit: Subreddit,
        action: @escaping () -> Void,
        isFavorite: Bool = false,
        onFavoriteToggle: (() -> Void)? = nil,
        isSubscribed: Bool? = nil,
        onSubscribeToggle: (() -> Void)? = nil
    ) {
        self.subreddit = subreddit
        self.action = action
        self.isFavorite = isFavorite
        self.onFavoriteToggle = onFavoriteToggle
        self.isSubscribed = isSubscribed
        self.onSubscribeToggle = onSubscribeToggle
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SubredditIcon(
                    iconURL: subreddit.iconURL,
                    displayName: subreddit.displayName,
                    size: 32
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(subreddit.displayNamePrefixed)
                        .appFont(.body, weight: .medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 4) {
                        Text("\(subreddit.memberCountText) members")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        
                        if subreddit.isNsfw {
                            Text("NSFW")
                                .appFont(.small)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.red, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                
                Spacer()

                if let isSubscribed = isSubscribed, let onSubscribeToggle = onSubscribeToggle {
                    if isSubscribed {
                        HStack(spacing: 6) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { showUnsubscribeConfirm.toggle() }
                            } label: {
                                Text("Subscribed")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)

                            if showUnsubscribeConfirm {
                                Button(role: .destructive) {
                                    HapticManager.shared.gentleImpact()
                                    showUnsubscribeConfirm = false
                                    onSubscribeToggle()
                                } label: {
                                    Text("Unsubscribe")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.red.opacity(0.15)))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    } else {
                        Button(action: {
                            HapticManager.shared.gentleImpact()
                            onSubscribeToggle()
                        }) {
                            Text("Subscribe")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.blue))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }

                if let onFavoriteToggle = onFavoriteToggle {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SubredditIcon: View {
    let iconURL: URL?
    let displayName: String
    let size: CGFloat
    
    var body: some View {
        Group {
            if let iconURL = iconURL {
                LazyImage(url: iconURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        SubredditIconPlaceholder(displayName: displayName)
                    }
                }
            } else {
                SubredditIconPlaceholder(displayName: displayName)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct SubredditIconPlaceholder: View {
    let displayName: String
    
    private var initials: String {
        let components = displayName.components(separatedBy: CharacterSet.letters.inverted)
        let letters = components.compactMap { $0.first }.prefix(2)
        return String(letters).uppercased()
    }
    
    private var backgroundColor: Color {
        let hash = displayName.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [backgroundColor, backgroundColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(initials.isEmpty ? "r/" : initials)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    let sampleJSON1 = """
    {
        "id": "2qh33",
        "display_name": "funny",
        "display_name_prefixed": "r/funny",
        "title": "funny",
        "description": "Welcome to r/Funny",
        "subscribers": 52000000,
        "over18": false,
        "public_description": "A place for funny content"
    }
    """.data(using: .utf8)!
    
    let sampleJSON2 = """
    {
        "id": "2qh34",
        "display_name": "nsfw",
        "display_name_prefixed": "r/nsfw",
        "title": "NSFW Content",
        "description": "Not safe for work",
        "subscribers": 1500,
        "over18": true,
        "public_description": "Adult content"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    let sampleSubreddit1 = try! decoder.decode(Subreddit.self, from: sampleJSON1)
    let sampleSubreddit2 = try! decoder.decode(Subreddit.self, from: sampleJSON2)
    
    return VStack(spacing: 0) {
        SubredditRow(subreddit: sampleSubreddit1) {
        }
        
        Divider()
            .padding(.leading, 60)
        
        SubredditRow(subreddit: sampleSubreddit2) {
        }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
}
