import UIKit
import AVFoundation

/// Lightweight AVPlayer-backed view for inline video playback.
/// - Uses `AVPlayerLayer` as backing layer.
/// - Manages looping and replaces items safely.
final class VideoPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    /// Controls how the video is scaled within the view.
    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    /// When true, restarts playback at end.
    var isLooping: Bool = false

    /// Current asset to play. Setting a new asset replaces the player item.
    var asset: AVAsset? {
        didSet { replaceCurrentAsset() }
    }

    private var endObserver: NSObjectProtocol?

    deinit {
        removeEndObserver()
        playerLayer.player?.pause()
        playerLayer.player = nil
    }

    func play() {
        guard let player = ensurePlayer() else { return }
        player.play()
        attachEndObserverIfNeeded(for: player.currentItem)
    }

    func pause() { playerLayer.player?.pause() }

    private func ensurePlayer() -> AVPlayer? {
        if let p = playerLayer.player { return p }
        let p = AVPlayer()
        playerLayer.player = p
        return p
    }

    private func replaceCurrentAsset() {
        removeEndObserver()
        guard let asset else { return }
        let item = AVPlayerItem(asset: asset)
        let player = ensurePlayer()
        player?.replaceCurrentItem(with: item)
        attachEndObserverIfNeeded(for: item)
    }

    /// Replaces the current player item with a provided item (used when item is preconfigured).
    func setPlayerItem(_ item: AVPlayerItem) {
        removeEndObserver()
        let player = ensurePlayer()
        player?.replaceCurrentItem(with: item)
        attachEndObserverIfNeeded(for: item)
    }

    private func attachEndObserverIfNeeded(for item: AVPlayerItem?) {
        guard isLooping, let item else { return }
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, let player = self.playerLayer.player else { return }
            player.seek(to: .zero)
            player.play()
        }
    }

    private func removeEndObserver() {
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
    }
}
