import SwiftUI
import Nuke
import NukeVideo
import AVFoundation

/// SwiftUI wrapper around `VideoPlayerView` which loads the AVAsset via Nuke
/// using the NukeVideo `ImageDecoders.Video` decoder.
struct NukeVideoPlayer: UIViewRepresentable {
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
            resumeMuted: resumeMuted
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
            resumeMuted: resumeMuted
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var currentURL: URL?
        private var task: ImageTask?
        private var timeObserver: Any?
        private weak var player: AVPlayer?
        private var lastResumeTime: Double? = nil
        private var lastResumeMuted: Bool? = nil

        func load(
            url: URL,
            into view: VideoPlayerView,
            onReady: (() -> Void)?,
            onError: ((Error?) -> Void)?,
            onPlayerAvailable: ((AVPlayer) -> Void)?,
            onTimeUpdate: ((Double) -> Void)?,
            resumeTime: Double?,
            resumeMuted: Bool?
        ) {
            if currentURL == url {
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
            currentURL = url
            task?.cancel()

            // Remove previous time observer if present
            if let observer = timeObserver, let p = player {
                p.removeTimeObserver(observer)
                timeObserver = nil
            }

            // Fast-path HLS: use AVURLAsset directly (decoder might not recognize .m3u8)
            if url.absoluteString.lowercased().contains(".m3u8") {
                // Debug removed: HLS detected
                let asset = AVURLAsset(url: url)
                view.asset = asset
                view.play()
                if let p = view.playerLayer.player {
                    self.player = p
                    DispatchQueue.main.async { onPlayerAvailable?(p) }
                    if let resumeMuted = resumeMuted { p.isMuted = resumeMuted }
                    if let resumeTime, resumeTime > 0.1 {
                        p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                    }
                    self.lastResumeTime = resumeTime
                    self.lastResumeMuted = resumeMuted
                    self.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                        onTimeUpdate?(t.seconds)
                    }
                }
                DispatchQueue.main.async { onReady?() }
                return
            }

            let request = ImageRequest(url: url)
            task = ImagePipeline.shared.loadImage(with: request) { result in
                switch result {
                case .success(let response):
                    let container = response.container
                    if let asset = container.userInfo[.videoAssetKey] as? AVAsset {
                        // Debug removed: AVAsset prepared
                        DispatchQueue.main.async {
                            view.asset = asset
                            view.play()
                            if let p = view.playerLayer.player {
                                self.player = p
                                DispatchQueue.main.async { onPlayerAvailable?(p) }
                                if let resumeMuted = resumeMuted { p.isMuted = resumeMuted }
                                if let resumeTime, resumeTime > 0.1 {
                                    p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                                }
                                self.lastResumeTime = resumeTime
                                self.lastResumeMuted = resumeMuted
                                self.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                                    onTimeUpdate?(t.seconds)
                                }
                            }
                            onReady?()
                        }
                    } else {
                        // Debug removed: fallback to AVURLAsset
                        DispatchQueue.main.async {
                            view.asset = AVURLAsset(url: url)
                            view.play()
                            if let p = view.playerLayer.player {
                                self.player = p
                                DispatchQueue.main.async { onPlayerAvailable?(p) }
                                if let resumeMuted = resumeMuted { p.isMuted = resumeMuted }
                                if let resumeTime, resumeTime > 0.1 {
                                    p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                                }
                                self.lastResumeTime = resumeTime
                                self.lastResumeMuted = resumeMuted
                                self.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                                    onTimeUpdate?(t.seconds)
                                }
                            }
                            onReady?()
                        }
                    }
                case .failure(let error):
                    // Debug removed: video load failed: \(error.localizedDescription); falling back to AVURLAsset")
                    DispatchQueue.main.async {
                        view.asset = AVURLAsset(url: url)
                        view.play()
                        if let p = view.playerLayer.player {
                            self.player = p
                            DispatchQueue.main.async { onPlayerAvailable?(p) }
                            if let resumeMuted = resumeMuted { p.isMuted = resumeMuted }
                            if let resumeTime, resumeTime > 0.1 {
                                p.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600)) { _ in p.play() }
                            }
                            self.lastResumeTime = resumeTime
                            self.lastResumeMuted = resumeMuted
                            self.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                                onTimeUpdate?(t.seconds)
                            }
                        }
                        onError?(error)
                        onReady?()
                    }
                }
            }
        }
    }
}
