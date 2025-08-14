//
//  CustomVideoPlayer.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct CustomVideoPlayer: UIViewRepresentable {
    let url: URL
    @Binding var player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black
        
        let player = AVPlayer(url: url)
        self.player = player
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = containerView.bounds
        containerView.layer.addSublayer(playerLayer)
        
        // Store the player layer for frame updates
        context.coordinator.playerLayer = playerLayer
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update player layer frame when view bounds change
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Alternative Clean Video Player
struct CleanVideoPlayer: View {
    let url: URL
    @Binding var player: AVPlayer?
    @State private var showControls = false
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            // Custom video view without gesture conflicts
            CustomVideoPlayer(url: url, player: $player)
                .onAppear {
                    setupPlayer()
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                    // Loop video when it ends
                    player?.seek(to: .zero)
                    player?.play()
                }
            
            // Custom minimal controls that don't interfere
            if showControls {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Simple play/pause button
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            
            // Hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }
    
    private func setupPlayer() {
        guard let player = player else { return }
        
        // Monitor playback state
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { _ in
            isPlaying = player.timeControlStatus == .playing
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
}

#Preview {
    @Previewable @State var player: AVPlayer? = nil
    
    CleanVideoPlayer(
        url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
        player: $player
    )
    .frame(height: 400)
}
