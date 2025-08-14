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
    let media: MediaItem
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            mediaContent
                .navigationTransition(.zoom(sourceID: media.id, in: namespace))
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .gesture(
            DragGesture()
                .onEnded { value in
                    if abs(value.translation.height) > 100 {
                        dismiss()
                    }
                }
        )
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
    
    @ViewBuilder
    private var mediaContent: some View {
        switch media.type {
        case .image(let url):
            LazyImage(url: URL(string: url)) { state in
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
            
        case .gif(let url):
            AnimatedGifView(url: url, contentMode: .scaleAspectFit, cornerRadius: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    dismiss()
                }
            
        case .video(let videoURL, _):
            if let url = URL(string: videoURL) {
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
            media: MediaItem(
                id: "test",
                type: .image(url: "https://example.com/image.jpg"),
                title: "Test Image"
            ),
            namespace: namespace
        )
    }
}
