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

    var body: some View {
        ZStack {
            if let data = gifData {
                FLAnimatedImageViewRepresentable(
                    data: data,
                    uiContentMode: (contentMode == .fill ? .scaleAspectFill : .scaleAspectFit),
                    cornerRadius: cornerRadius
                )
                .id(data.hashValue)
                .frame(maxWidth: .infinity)
                .frame(height: fixedHeight)
                .contentShape(Rectangle())
            } else if isLoading {
                placeholder
                    .overlay { ProgressView().scaleEffect(1.1) }
            } else if error != nil {
                errorView
            } else {
                placeholder
                    .onAppear { startLoad() }
            }
        }
        .onDisappear { cancelLoad() }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
    }

    private var errorView: some View {
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
            .frame(height: fixedHeight)
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
