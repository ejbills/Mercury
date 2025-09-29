import SwiftUI
import AVFoundation

/// SwiftUI wrapper around `VideoPlayerView` which streams video via AVFoundation.
///
/// This avoids routing video bytes through Nuke's pipeline, which can retain large
/// in‑memory buffers for MP4s and lead to memory pressure when many inline videos
/// are present. We stream directly with `AVURLAsset` and carefully manage
/// player/time observer lifecycle to prevent leaks.
struct NukeVideoPlayer: UIViewRepresentable {
    typealias UIViewType = VideoPlayerView
    let url: URL
    var cornerRadius: CGFloat = 12
    var isLooping: Bool = true
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var onReady: (() -> Void)? = nil
    var onError: ((Error?) -> Void)? = nil
    var onPlayerAvailable: ((AVPlayer) -> Void)? = nil
    var onTimeUpdate: ((Double) -> Void)? = nil
    var resumeTime: Double? = nil
    var resumeMuted: Bool? = nil
    // Changes to this token force a fresh load even if URL stays the same
    var reloadToken: Int = 0

    func makeUIView(context: Context) -> VideoPlayerView {
        let view = VideoPlayerView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = cornerRadius
        view.videoGravity = gravity
        view.isLooping = isLooping
        context.coordinator.load(
            url: url,
            into: view,
            onReady: onReady,
            onError: onError,
            onPlayerAvailable: onPlayerAvailable,
            onTimeUpdate: onTimeUpdate,
            resumeTime: resumeTime,
            resumeMuted: resumeMuted,
            reloadToken: reloadToken
        )
        return view
    }

    func updateUIView(_ uiView: VideoPlayerView, context: Context) {
        context.coordinator.load(
            url: url,
            into: uiView,
            onReady: onReady,
            onError: onError,
            onPlayerAvailable: onPlayerAvailable,
            onTimeUpdate: onTimeUpdate,
            resumeTime: resumeTime,
            resumeMuted: resumeMuted,
            reloadToken: reloadToken
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var lastURL: URL?
        private var lastReloadToken: Int = 0
        private var timeObserver: Any?
        private weak var player: AVPlayer?
        private var lastResumeTime: Double? = nil
        private var lastResumeMuted: Bool? = nil
        private var statusObservation: NSKeyValueObservation?
        private var failedObserver: NSObjectProtocol?

        deinit {
            cleanup()
        }

        private func cleanup() {
            if let observer = timeObserver, let p = player {
                p.removeTimeObserver(observer)
            }
            timeObserver = nil
            player?.pause()
            player = nil
            statusObservation?.invalidate()
            statusObservation = nil
            if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
            failedObserver = nil
        }

        func load(
            url: URL,
            into view: VideoPlayerView,
            onReady: (() -> Void)?,
            onError: ((Error?) -> Void)?,
            onPlayerAvailable: ((AVPlayer) -> Void)?,
            onTimeUpdate: ((Double) -> Void)?,
            resumeTime: Double?,
            resumeMuted: Bool?,
            reloadToken: Int
        ) {
            if lastURL == url && lastReloadToken == reloadToken {
                // Same URL: if we only need to apply new resume state, do it here
                if let p = view.playerLayer.player {
                    if let resumeMuted, resumeMuted != lastResumeMuted { p.isMuted = resumeMuted }
                    if let resumeTime, resumeTime > 0.1, resumeTime != lastResumeTime {
                        p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                    }
                    lastResumeTime = resumeTime
                    lastResumeMuted = resumeMuted
                }
                return
            }
            lastURL = url
            lastReloadToken = reloadToken
            // Clear previous observer/player
            cleanup()

            // Create asset and configure player
            let asset = AVURLAsset(url: url)
            // Prefer streaming without large forward buffers
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 0 // minimize forward buffer
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = false

            // Attach configured item to view/player
            view.setPlayerItem(item)
            view.play()

            // Keep weak ref and report availability
            self.player = view.playerLayer.player
            if let p = self.player {
                DispatchQueue.main.async { onPlayerAvailable?(p) }
                // Tune buffering to avoid large memory spikes
                p.automaticallyWaitsToMinimizeStalling = true
                if let resumeMuted { p.isMuted = resumeMuted }
                p.currentItem?.preferredForwardBufferDuration = 0
                p.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
                if let resumeTime, resumeTime > 0.1 {
                    p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                }
                self.lastResumeTime = resumeTime
                self.lastResumeMuted = resumeMuted
                self.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                    onTimeUpdate?(t.seconds)
                }

                // Observe status changes to report ready/error
                self.statusObservation = item.observe(\.status, options: [.initial, .new]) { item, _ in
                    switch item.status {
                    case .readyToPlay:
                        DispatchQueue.main.async { onReady?() }
                    case .failed:
                        let err = item.error
                        if let e = err {
                            print("[Video] Player item failed: URL=\(url.absoluteString) error=\(e.localizedDescription)")
                        } else {
                            print("[Video] Player item failed: URL=\(url.absoluteString) error=(nil)")
                        }
                        if let log = item.errorLog() {
                            for ev in log.events {
                                print("[Video] ErrorLog: statusCode=\(ev.errorStatusCode) server=\(ev.serverAddress ?? "-") uri=\(ev.uri ?? "-") errorStatus=\(ev.errorStatusCode) errorDomain=\(ev.errorDomain) comment=\(ev.errorComment ?? "-")")
                            }
                        }
                        DispatchQueue.main.async { onError?(err) }
                    default:
                        break
                    }
                }

                // Observe failure to play to end
                self.failedObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemFailedToPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    let err = p.currentItem?.error
                    if let e = err {
                        print("[Video] Failed to play to end: URL=\(url.absoluteString) error=\(e.localizedDescription)")
                    } else {
                        print("[Video] Failed to play to end: URL=\(url.absoluteString) error=(nil)")
                    }
                    onError?(err)
                }

                // Looping support is handled by VideoPlayerView.isLooping
            }
            // onReady is fired via statusObservation when ready
        }
    }
}
