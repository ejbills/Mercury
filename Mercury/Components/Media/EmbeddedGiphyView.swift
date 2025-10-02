import SwiftUI

struct EmbeddedGiphyView: View {
    let source: String // either giphy token (giphy|ID) or a giphy URL
    @State private var resolvedURL: URL? = nil
    @State private var intrinsicSize: CGSize? = nil
    private let defaultHeight: CGFloat = 300

    var body: some View {
        Group {
            if let url = resolvedURL {
                // Let the inner GIF view size itself by aspect ratio after load
                FLAnimatedGifView(
                    url: url,
                    contentMode: .fit,
                    cornerRadius: 12,
                    fixedHeight: nil
                )
                .frame(maxWidth: .infinity)
            } else {
                // No fixed height while resolving token; avoid locking parent
                Color.clear
                    .overlay { ProgressView().scaleEffect(1.1) }
                    .task { await resolve() }
            }
        }
    }

    private func height(for width: CGFloat) -> CGFloat {
        if let sz = intrinsicSize, sz.width > 0 {
            return max(180, min(420, width * (sz.height / sz.width)))
        } else {
            return defaultHeight
        }
    }

    private func resolve() async {
        // If already a direct media.giphy.com link, use it as-is
        if let direct = directMediaURL(from: source) {
            await MainActor.run {
                self.resolvedURL = direct.url
                self.intrinsicSize = direct.size
            }
            return
        }

        // Handle Reddit giphy token formats using API for dimensions
        if source.lowercased().hasPrefix("giphy|") || source.lowercased().hasPrefix("giphy%7c") {
            if let media = await GiphyService.resolveGiphyMedia(from: source), let url = URL(string: media.url) {
                await MainActor.run {
                    self.resolvedURL = url
                    self.intrinsicSize = media.dimensions
                }
            }
            return
        }

        // Handle giphy.com page URL by converting to media URL with best-effort ID extraction
        if let transformed = transformGiphyPageURL(source), let url = URL(string: transformed) {
            await MainActor.run {
                self.resolvedURL = url
                self.intrinsicSize = nil
            }
        }
    }

    private func transformGiphyPageURL(_ url: String) -> String? {
        guard let comps = URLComponents(string: url), let host = comps.host else { return nil }
        let lowerHost = host.lowercased()
        if lowerHost.contains("media.giphy.com") { return url }
        if !lowerHost.contains("giphy.com") { return nil }
        // Try to extract ID from last path component (often slug contains -<id>)
        let path = comps.path
        // Common: /gifs/<slug>-<id>
        if let id = path.components(separatedBy: "/").last?.components(separatedBy: "-").last, id.count >= 5 {
            return "https://media.giphy.com/media/\(id)/giphy.gif"
        }
        return nil
    }

    private func directMediaURL(from s: String) -> (url: URL, size: CGSize?)? {
        guard let u = URL(string: s) else { return nil }
        let host = u.host?.lowercased() ?? ""
        if host.contains("media.giphy.com") { return (u, nil) }
        return nil
    }
}
