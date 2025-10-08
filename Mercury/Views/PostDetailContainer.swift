// PostDetailContainer.swift
// Mercury

import SwiftUI

/// Container that reactively passes the latest videoHandoffState to PostDetailRouter
struct PostDetailContainer: View {
    let post: RedditPost
    let namespace: Namespace.ID
    @Binding var videoHandoffState: VideoHandoffState?
    let onDismiss: () -> Void
    
    var body: some View {
        PostDetailRouter(
            post: post,
            namespace: namespace,
            videoHandoffState: videoHandoffState,  // This is now reactive!
            onVideoHandoffReturn: { returnedState in
                videoHandoffState = returnedState
                onDismiss()
            },
            onDismiss: onDismiss
        )
    }
}
