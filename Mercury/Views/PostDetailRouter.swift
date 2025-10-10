// PostDetailRouter.swift
// Mercury

import SwiftUI

struct PostDetailRouter: View {
    let post: RedditPost
    let namespace: Namespace.ID
    let videoHandoffState: VideoHandoffState?
    let onVideoHandoffReturn: ((VideoHandoffState) -> Void)?
    let onDismiss: (() -> Void)?
    
    var body: some View {
        switch post.postType {
        case .gallery, .image, .gif, .video:
            MediaDetailView(
                post: post, 
                namespace: namespace, 
                videoHandoffState: videoHandoffState,
                onVideoHandoffReturn: onVideoHandoffReturn
            )
        case .text, .link:
            UnsupportedMediaDetailView(onDismiss: onDismiss)
        }
    }
}

private struct UnsupportedMediaDetailView: View {
    let onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "doc.text")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.secondary)

                Text("Content Not Supported")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("This post can't be opened in the media viewer. Try viewing it in the full post instead.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Close") {
                    dismissView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .topLeading) {
            Button(action: dismissView) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(.top, 16)
            .padding(.leading, 16)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(.systemBackground)
    }

    private func dismissView() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    
    PostDetailRouter(
        post: RedditPost.samplePost,
        namespace: namespace,
        videoHandoffState: nil,
        onVideoHandoffReturn: nil,
        onDismiss: {}
    )
}
