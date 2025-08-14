//
//  MediaDetailView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import AVKit
import Nuke
import NukeUI

struct MediaDetailView: View {
    @State var post: RedditPost
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.redditAPI) private var redditAPI
    @State private var player: AVPlayer?
    @State private var hasAppeared = false

    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
                mediaContent
                    .navigationTransition(.zoom(sourceID: mediaId, in: namespace))
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                
                Spacer()
            }
            .padding([.horizontal, .top], 20)
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            // Clean up video player
            if let player = player {
                player.pause()
                player.seek(to: .zero)
                self.player = nil
            }
        }
    }
    
    private var mediaId: String {
        "\(post.id)-\(post.postType.displayName.lowercased())"
    }
    
    @ViewBuilder
    private var mediaContent: some View {
        switch post.postType {
        case .image:
            if let imageURL = post.imageURL {
                LazyImage(url: URL(string: imageURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture {
                                dismiss()
                            }
                    } else if state.error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                            Text("Failed to load image")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
            
        case .gif:
            if let gifURL = post.gifURL, let url = URL(string: gifURL) {
                AnimatedGifView(url: url, contentMode: .scaleAspectFit, cornerRadius: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        dismiss()
                    }
            }
            
        case .video:
            if let videoURL = post.videoURL, let url = URL(string: videoURL) {
                VideoPlayer(player: player ?? AVPlayer(url: url))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: url)
                        }
                        // Auto-play when appearing
                        player?.play()
                    }
                    .onTapGesture {
                        // Let video player handle its own controls
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text("Failed to load video")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        case .text, .link:
            // These shouldn't appear in media detail view
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("Content not available in media view")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
    }
    

}

struct MediaItem: Identifiable, Hashable {
    let id: String
    let type: MediaType
    let title: String?
    
    enum MediaType: Hashable {
        case image(url: String)
        case gif(url: URL)
        case video(url: String, thumbnailURL: String?)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    
    NavigationStack {
        MediaDetailView(
            post: RedditPost.samplePost,
            namespace: namespace
        )
        .environment(\.redditAPI, RedditAPIService())
    }
}
