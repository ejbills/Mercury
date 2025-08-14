//
//  MoreMenuView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct MoreMenuView: View {
    let post: RedditPost
    let onShare: () -> Void
    let onSave: () -> Void
    let onCopyLink: () -> Void
    let onOpenOriginal: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onSave) {
                Label(post.saved ? "Unsave" : "Save", systemImage: post.saved ? "bookmark.fill" : "bookmark")
            }
            
            Button(action: onCopyLink) {
                Label("Copy Link", systemImage: "link")
            }
            
            if let urlString = post.url, !urlString.isEmpty {
                Button(action: onOpenOriginal) {
                    Label("Open Original", systemImage: "safari")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel("More options")
    }
}

struct MoreMenuViewCompact: View {
    let post: RedditPost
    let onShare: () -> Void
    let onSave: () -> Void
    let onCopyLink: () -> Void
    let onOpenOriginal: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onSave) {
                Label(post.saved ? "Unsave" : "Save", systemImage: post.saved ? "bookmark.fill" : "bookmark")
            }
            
            Button(action: onCopyLink) {
                Label("Copy Link", systemImage: "link")
            }
            
            if let urlString = post.url, !urlString.isEmpty {
                Button(action: onOpenOriginal) {
                    Label("Open Original", systemImage: "safari")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .accessibilityLabel("More options")
    }
}

#Preview {
    VStack(spacing: 20) {
        MoreMenuView(
            post: RedditPost.samplePost,
            onShare: {},
            onSave: {},
            onCopyLink: {},
            onOpenOriginal: {}
        )
        
        MoreMenuViewCompact(
            post: RedditPost.samplePost,
            onShare: {},
            onSave: {},
            onCopyLink: {},
            onOpenOriginal: {}
        )
    }
    .padding()
}
