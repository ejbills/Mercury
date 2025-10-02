import SwiftUI
import Nuke
import FLAnimatedImage
import UIKit

/// GIF view backed by Nuke pipeline (data) and rendered with FLAnimatedImage.
struct FLAnimatedGifView: View {
    let url: URL
    var contentMode: ContentMode = .fit
    var cornerRadius: CGFloat = 12
    var fixedHeight: CGFloat? = nil

    @State private var gifData: Data? = nil
    @State private var isLoading = false
    @State private var error: Error? = nil
    @State private var task: ImageTask? = nil
    @State private var aspectRatio: CGFloat? = nil // height / width

    var body: some View {
        ZStack {
            if let data = gifData {
                // If a fixedHeight is provided, use it; otherwise size by aspect ratio
                let view = FLAnimatedImageViewRepresentable(
                    data: data,
                    uiContentMode: (contentMode == .fill ? .scaleAspectFill : .scaleAspectFit),
                    cornerRadius: cornerRadius
                )
                .id(data.hashValue)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

                if let fixedHeight {
                    view.frame(height: fixedHeight)
                } else if let ar = aspectRatio, ar > 0 {
                    // aspectRatio expects width/height. We have height/width.
                    view.aspectRatio(1.0 / ar, contentMode: .fit)
                } else {
                    view.frame(height: 220)
                }
            } else if isLoading {
                // Do not impose a height while loading so we don't lock the parent size
                Color.clear
                    .frame(maxWidth: .infinity)
                    .overlay { ProgressView().scaleEffect(1.1) }
            } else if error != nil {
                // Show a lightweight error state without fixing height
                Color.clear
                    .frame(maxWidth: .infinity)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                            Text("Failed to load GIF").font(.caption).foregroundStyle(.secondary)
                        }
                    }
            } else {
                // Initial state: trigger load without constraining height
                Color.clear
                    .frame(maxWidth: .infinity)
                    .overlay { ProgressView().scaleEffect(1.1) }
                    .onAppear { startLoad() }
            }
        }
        .onDisappear { cancelLoad() }
    }

    private func placeholder(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func errorView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary.opacity(0.3))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text("Failed to load GIF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func startLoad() {
        guard task == nil else { return }
        isLoading = true
        error = nil
        let request = ImageRequest(url: url)
        task = ImagePipeline.shared.loadData(with: request) { result in
            switch result {
            case .success(let response):
                let data = response.data
                DispatchQueue.main.async {
                    self.gifData = data
                    self.isLoading = false
                    // Derive aspect ratio from GIF frames
                    if let animated = FLAnimatedImage(animatedGIFData: data) {
                        let sz = animated.size
                        if sz.width > 0 { self.aspectRatio = sz.height / sz.width }
                    }
                    
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = error
                    
                }
            }
        }
    }

    private func cancelLoad() {
        task?.cancel()
        task = nil
    }
}

// MARK: - FLAnimatedImage SwiftUI wrapper
private struct FLAnimatedImageViewRepresentable: UIViewRepresentable {
    let data: Data
    let uiContentMode: UIView.ContentMode
    let cornerRadius: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FLAnimatedImageView {
        let view = FLAnimatedImageView()
        view.contentMode = uiContentMode
        view.clipsToBounds = true
        view.layer.cornerRadius = cornerRadius
        // Avoid oversized intrinsic sizing that can push parent layout beyond screen
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let animated = FLAnimatedImage(animatedGIFData: data)
        view.animatedImage = animated
        context.coordinator.currentData = data as NSData
        return view
    }

    func updateUIView(_ uiView: FLAnimatedImageView, context: Context) {
        if context.coordinator.currentData !== data as NSData {
            let animated = FLAnimatedImage(animatedGIFData: data)
            uiView.animatedImage = animated
            context.coordinator.currentData = data as NSData
        }
        uiView.contentMode = uiContentMode
        uiView.layer.cornerRadius = cornerRadius
    }

    final class Coordinator { var currentData: NSData? }
}
