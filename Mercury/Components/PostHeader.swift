import SwiftUI

struct PostHeader: View {
    let post: RedditPost
    let colorScheme: PostHeaderColorScheme
    @Environment(\.navigationPathManager) private var navigationPath
    
    init(post: RedditPost, colorScheme: PostHeaderColorScheme = .light) {
        self.post = post
        self.colorScheme = colorScheme
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Pill(action: {
                navigationPath.navigate(to: .subredditFeed(subreddit: post.subreddit))
            }) {
                Text(post.displaySubreddit)
                    .foregroundStyle(colorScheme.primaryTextColor)
                    .appFont(.meta)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Pill(action: {
                navigationPath.navigate(to: .userProfile(username: post.author))
            }) {
                HStack(alignment: .center, spacing: 6) {
                    UserAvatar(username: post.author, size: 16, iconURL: post.authorIconURL)
                    Text(post.timeAgo)
                        .appFont(.small)
                        .foregroundStyle(colorScheme.tertiaryTextColor)
                                        
                    Text(post.author)
                        .foregroundStyle(colorScheme.secondaryTextColor)
                        .appFont(.meta)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}

enum PostHeaderColorScheme {
    case light
    case dark
    
    var primaryTextColor: Color {
        switch self {
        case .light: return .primary
        case .dark: return .white
        }
    }
    
    var secondaryTextColor: Color {
        switch self {
        case .light: return .secondary
        case .dark: return .gray
        }
    }
    
    var tertiaryTextColor: Color {
        switch self {
        case .light: return Color(UIColor.tertiaryLabel)
        case .dark: return .gray.opacity(0.7)
        }
    }
    
    var accentTextColor: Color {
        switch self {
        case .light: return .blue
        case .dark: return .blue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PostHeader(post: RedditPost.samplePost, colorScheme: .light)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        
        PostHeader(post: RedditPost.samplePost, colorScheme: .dark)
            .padding()
            .background(.black, in: RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
