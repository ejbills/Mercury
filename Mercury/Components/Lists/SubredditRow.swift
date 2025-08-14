//
//  SubredditRow.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Nuke
import NukeUI

struct SubredditRow: View {
    let subreddit: Subreddit
    let action: () -> Void
    
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
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(subreddit.memberCountText) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if subreddit.isNsfw {
                            Text("NSFW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.red, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
            // Handle subreddit tap
        }
        
        Divider()
            .padding(.leading, 60)
        
        SubredditRow(subreddit: sampleSubreddit2) {
            // Handle NSFW subreddit tap
        }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
}
