import SwiftUI
import Nuke
import SSSwiftUIGIFView
import CryptoKit

/// GIF view backed by Nuke pipeline (data) and rendered with SSSwiftUIGIFView.
struct NukeGifView: View {
    let url: URL
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 12
    var fixedHeight: CGFloat? = nil

    @State private var localURL: URL? = nil
    @State private var isLoading = false
    @State private var error: Error? = nil
    @State private var task: ImageTask? = nil

    var body: some View {
        ZStack {
            if let localURL {
                SwiftUIGIFPlayerView(gifURL: localURL, gifName: nil, isShowProgressView: false) {
                    placeholder
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .frame(maxWidth: .infinity)
                .frame(height: fixedHeight)
                .contentShape(Rectangle())
            } else if isLoading {
                placeholder.overlay { ProgressView().scaleEffect(1.1) }
            } else if error != nil {
                errorView
            } else {
                placeholder
                    .onAppear { startLoad() }
            }
        }
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
                do {
                    let fileURL = try writeDataToCache(data: data, for: url)
                    DispatchQueue.main.async {
                        self.localURL = fileURL
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = error
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

    private func writeDataToCache(data: Data, for url: URL) throws -> URL {
        let hash = Insecure.MD5.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02hhx", $0) }.joined()
        let fileName = "\(hash).gif"
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gif-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
