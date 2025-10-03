// SimpleVideoPlayer.swift
// Mercury

import SwiftUI
import AVFoundation
import AVKit

struct SimpleVideoPlayer: View {
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

    var body: some View {
        Group {
            if showControls {
                PlayerViewControllerRepresentable(player: player, shouldLoop: shouldLoop, autoPlay: autoPlay, gravity: gravity)
            } else {
                PlayerLayerRepresentable(player: player, shouldLoop: shouldLoop, autoPlay: autoPlay, gravity: gravity)
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable for AVPlayerViewController (with controls)
private struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let shouldLoop: Bool
    let autoPlay: Bool
    let gravity: AVLayerVideoGravity

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        configureAudioSession()
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.updatesNowPlayingInfoCenter = false
        controller.videoGravity = gravity
        if shouldLoop {
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        if autoPlay { player.play() }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.videoGravity = gravity
        if controller.player !== player { controller.player = player }
    }

    func makeCoordinator() -> Coordinator { Coordinator(shouldLoop: shouldLoop, player: player) }

    class Coordinator {
        let shouldLoop: Bool
        let player: AVPlayer
        init(shouldLoop: Bool, player: AVPlayer) { self.shouldLoop = shouldLoop; self.player = player }
        @objc func playerDidFinish() {
            if shouldLoop {
                player.seek(to: CMTime(seconds: 0.001, preferredTimescale: 600))
                player.play()
            }
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

// MARK: - UIViewRepresentable for AVPlayerLayer (no controls)
private struct PlayerLayerRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let shouldLoop: Bool
    let autoPlay: Bool
    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerContainerView {
        configureAudioSession()
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        let playerLayer = view.playerLayer
        CATransaction.begin(); CATransaction.setDisableActions(true)
        playerLayer.player = player
        playerLayer.videoGravity = gravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.frame = view.bounds
        CATransaction.commit()
        context.coordinator.playerLayer = playerLayer
        if shouldLoop {
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        if autoPlay { player.play() }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            playerLayer.videoGravity = gravity
            playerLayer.frame = uiView.bounds
            if playerLayer.player !== player { playerLayer.player = player }
            playerLayer.removeAllAnimations()
            CATransaction.commit()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(shouldLoop: shouldLoop, player: player) }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
        let shouldLoop: Bool
        let player: AVPlayer
        init(shouldLoop: Bool, player: AVPlayer) { self.shouldLoop = shouldLoop; self.player = player }
        @objc func playerDidFinish() {
            if shouldLoop {
                player.seek(to: CMTime(seconds: 0.001, preferredTimescale: 600))
                player.play()
            }
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

// Shared
private func configureAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try audioSession.setActive(true)
    } catch {
        // Silent failure ok
    }
}

private final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}
