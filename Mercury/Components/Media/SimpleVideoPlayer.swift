// SimpleVideoPlayer.swift
// Mercury

import SwiftUI
import AVFoundation
import AVKit

struct SimpleVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let showControls: Bool
    let shouldLoop: Bool
    let autoPlay: Bool
    let gravity: AVLayerVideoGravity
    
    init(player: AVPlayer, showControls: Bool, shouldLoop: Bool, autoPlay: Bool, gravity: AVLayerVideoGravity = .resizeAspectFill) {
        self.player = player
        self.showControls = showControls
        self.shouldLoop = shouldLoop
        self.autoPlay = autoPlay
        self.gravity = gravity
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        
        if showControls {
            let controller = AVPlayerViewController()
            controller.player = player
            controller.showsPlaybackControls = true
            controller.updatesNowPlayingInfoCenter = false
            controller.videoGravity = gravity
            controller.view.backgroundColor = UIColor.clear
            
            view.addSubview(controller.view)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            context.coordinator.playerController = controller
        } else {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = gravity
            playerLayer.backgroundColor = UIColor.clear.cgColor
            playerLayer.frame = view.bounds
            playerLayer.needsDisplayOnBoundsChange = true
            view.layer.addSublayer(playerLayer)
            
            context.coordinator.playerLayer = playerLayer
        }
        
        if shouldLoop {
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        
        if autoPlay {
            player.play()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            // Force frame update on main thread
            DispatchQueue.main.async {
                playerLayer.videoGravity = gravity
                playerLayer.frame = uiView.bounds
                if playerLayer.player !== player {
                    playerLayer.player = player
                }
                // Force display update
                playerLayer.setNeedsDisplay()
            }
        }
        
        if let controller = context.coordinator.playerController {
            controller.view.frame = uiView.bounds
            controller.videoGravity = gravity
            if controller.player !== player {
                controller.player = player
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(shouldLoop: shouldLoop, player: player)
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
        var playerController: AVPlayerViewController?
        let shouldLoop: Bool
        let player: AVPlayer
        
        init(shouldLoop: Bool, player: AVPlayer) {
            self.shouldLoop = shouldLoop
            self.player = player
        }
        
        @objc func playerDidFinish() {
            if shouldLoop {
                player.seek(to: CMTime(seconds: 0.001, preferredTimescale: 600))
                player.play()
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
