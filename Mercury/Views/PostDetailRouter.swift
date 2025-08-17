//
//  PostDetailRouter.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

struct PostDetailRouter: View {
    let post: RedditPost
    let namespace: Namespace.ID
    
    var body: some View {
        switch post.postType {
        case .gallery:
            GalleryDetailView(post: post, namespace: namespace)
        case .image, .gif, .video:
            MediaDetailView(post: post, namespace: namespace)
        case .text, .link:
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
        namespace: namespace
    )
}
