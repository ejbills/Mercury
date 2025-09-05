import SwiftUI
import Nuke
import ImageIO

/// A scrubbable GIF player built with CoreGraphics decoding for precise frame control.
struct ScrubbableGifView: View {
    let url: URL
    var contentMode: ContentMode = .fit
    var cornerRadius: CGFloat = 0
    @Binding var progress: Double // 0...1
    var isScrubbing: Bool // when true, pause playback and use `progress` as source of truth

    @State private var data: Data? = nil
    @State private var task: ImageTask? = nil

    var body: some View {
        ZStack {
            if let data {
                let dataId = data.hashValue
                ScrubbableGIFPlayerViewRepresentable(
                    data: data,
                    dataId: dataId,
                    progress: $progress,
                    isScrubbing: isScrubbing,
                    uiContentMode: (contentMode == .fill ? .scaleAspectFill : .scaleAspectFit),
                    cornerRadius: cornerRadius
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.quaternary.opacity(0.3))
                    .overlay { ProgressView().scaleEffect(1.1) }
            }
        }
        .onAppear(perform: startLoad)
        .onDisappear(perform: cancelLoad)
    }

    private func startLoad() {
        guard task == nil else { return }
        let req = ImageRequest(url: url)
        task = ImagePipeline.shared.loadData(with: req) { result in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self.data = resp.data }
            case .failure:
                break
            }
        }
    }

    private func cancelLoad() {
        task?.cancel(); task = nil
    }
}

// MARK: - UIKit player with CADisplayLink
private struct ScrubbableGIFPlayerViewRepresentable: UIViewRepresentable {
    let data: Data
    let dataId: Int
    @Binding var progress: Double
    let isScrubbing: Bool
    let uiContentMode: UIView.ContentMode
    let cornerRadius: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = uiContentMode
        v.clipsToBounds = true
        v.layer.cornerRadius = cornerRadius
        // Avoid proposing oversized intrinsic dimensions that can stretch parent containers
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        context.coordinator.imageView = v
        context.coordinator.configure(with: data, dataId: dataId)
        context.coordinator.onProgress = { p in
            // Debounce tiny fluctuations
            if abs(progress - p) > 0.002 { progress = p }
        }
        context.coordinator.start()
        return v
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = uiContentMode
        uiView.layer.cornerRadius = cornerRadius
        if context.coordinator.dataId != dataId {
            context.coordinator.configure(with: data, dataId: dataId)
        }
        // Apply external scrubbing
        context.coordinator.isScrubbing = isScrubbing
        context.coordinator.setProgress(progress)
    }

    final class Coordinator {
        weak var imageView: UIImageView?
        var displayLink: CADisplayLink?
        var rawData: Data?
        var dataId: Int = 0
        var frames: [UIImage] = []
        var frameDurations: [Double] = []
        var cumulative: [Double] = []
        var totalDuration: Double = 0
        var elapsed: Double = 0
        var isScrubbing: Bool = false
        var onProgress: ((Double) -> Void)?

        func configure(with data: Data, dataId: Int) {
            rawData = data
            self.dataId = dataId
            frames.removeAll(); frameDurations.removeAll(); cumulative.removeAll()
            totalDuration = 0; elapsed = 0

            guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let count = CGImageSourceGetCount(src)
            frames.reserveCapacity(count)
            frameDurations.reserveCapacity(count)

            for i in 0..<count {
                if let cg = CGImageSourceCreateImageAtIndex(src, i, nil) {
                    frames.append(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up))
                }
                let dur = Self.frameDuration(at: i, source: src)
                frameDurations.append(dur)
                totalDuration += dur
                cumulative.append(totalDuration)
            }

            // Show first frame
            imageView?.image = frames.first

            
        }

        func start() {
            stop()
            displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink?.add(to: .main, forMode: .common)
            
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            
        }

        var lastTickLog: CFTimeInterval = 0

        @objc func tick() {
            guard !frames.isEmpty, totalDuration > 0, let iv = imageView else { return }
            if !isScrubbing {
                elapsed += displayLink?.duration ?? 0
                if elapsed > totalDuration { elapsed = elapsed.truncatingRemainder(dividingBy: totalDuration) }
            }
            let idx = frameIndex(for: elapsed)
            iv.image = frames[idx]
            if !isScrubbing { onProgress?(elapsed / totalDuration) }

            
        }

        func setProgress(_ p: Double) {
            guard isScrubbing, totalDuration > 0 else { return }
            let clamped = max(0, min(1, p))
            elapsed = clamped * totalDuration
            if let iv = imageView, !frames.isEmpty {
                iv.image = frames[frameIndex(for: elapsed)]
            }
            
        }

        func frameIndex(for time: Double) -> Int {
            // Find first cumulative >= time
            if cumulative.isEmpty { return 0 }
            var low = 0, high = cumulative.count - 1, ans = high
            while low <= high {
                let mid = (low + high) / 2
                if cumulative[mid] >= time { ans = mid; high = mid - 1 } else { low = mid + 1 }
            }
            return min(max(ans, 0), frames.count - 1)
        }

        static func frameDuration(at index: Int, source: CGImageSource) -> Double {
            let defaultFrameDuration = 0.1
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
                return defaultFrameDuration
            }
            let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
            let val = (unclamped ?? clamped ?? defaultFrameDuration)
            // Safari/Chrome minimum frame duration behavior
            return max(val, 0.02)
        }

        deinit { stop() }
    }
}
