// PostDetailRouter.swift
// Mercury

import SwiftUI

struct PostDetailRouter: View {
    let post: RedditPost
    let namespace: Namespace.ID
    let videoHandoffState: VideoHandoffState?
    let onVideoHandoffReturn: ((VideoHandoffState) -> Void)?
    
    var body: some View {
        switch post.postType {
        case .gallery, .image, .gif, .video:
            MediaDetailView(
                post: post, 
                namespace: namespace, 
                videoHandoffState: videoHandoffState, 
                onVideoHandoffReturn: onVideoHandoffReturn
            )
        case .text, .link, .youtube:
            // For text and link posts, we could show a different view or fallback
            // For now, just dismiss since these shouldn't trigger media detail
            Text("Unsupported post type for detail view")
                .foregroundStyle(.white)
                .background(Color.black)
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    
    PostDetailRouter(
        post: RedditPost.samplePost,
        namespace: namespace,
        videoHandoffState: nil,
        onVideoHandoffReturn: nil
    )
}
