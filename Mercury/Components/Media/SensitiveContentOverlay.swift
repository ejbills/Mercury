import SwiftUI
import Defaults

struct SensitiveContentOverlay: View {
    let post: RedditPost
    let contentType: ContentType
    @Binding var isBlurred: Bool
    @Default(.blurNSFWContent) private var blurNSFWContent
    @Default(.blurSpoilerContent) private var blurSpoilerContent

    enum ContentType {
        case image
        case video
        case gif
        case gallery
        case text
        case link
    }

    private enum Reason: String {
        case nsfw = "NSFW"
        case spoiler = "Spoiler"

        var displayLabel: String { rawValue.uppercased() }
    }

    private var activeReasons: [Reason] {
        var reasons: [Reason] = []
        if post.isNsfw && blurNSFWContent {
            reasons.append(.nsfw)
        }
        if post.isSpoiler && blurSpoilerContent {
            reasons.append(.spoiler)
        }
        return reasons
    }

    private var overlayTitle: String {
        let reasonText = activeReasons.map { $0.displayLabel }.joined(separator: " & ")
        guard !reasonText.isEmpty else { return "" }

        switch contentType {
        case .gallery:
            return "\(reasonText) Gallery"
        case .text:
            return "\(reasonText) Text"
        case .link:
            return "\(reasonText) Link"
        default:
            return "\(reasonText) Content"
        }
    }

    private var shouldShow: Bool {
        !activeReasons.isEmpty && isBlurred
    }

    var body: some View {
        if shouldShow {
            ZStack {
                Color.black.opacity(0.7)
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    if !overlayTitle.isEmpty {
                        Text(overlayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("Tap to reveal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBlurred = false
                }
            }
            .transition(.opacity)
        }
    }
}

private struct SensitiveContentBlurModifier: ViewModifier {
    let post: RedditPost
    let contentType: SensitiveContentOverlay.ContentType
    @Binding var isBlurred: Bool
    let cornerRadius: CGFloat?
    @Default(.blurNSFWContent) private var blurNSFWContent
    @Default(.blurSpoilerContent) private var blurSpoilerContent

    private var shouldBlur: Bool {
        (post.isNsfw && blurNSFWContent) || (post.isSpoiler && blurSpoilerContent)
    }

    func body(content: Content) -> some View {
        let blurred = ZStack {
            content
                .blur(radius: shouldBlur && isBlurred ? 20 : 0)
            SensitiveContentOverlay(post: post, contentType: contentType, isBlurred: $isBlurred)
        }
        .onAppear {
            isBlurred = shouldBlur
        }
        .onChange(of: shouldBlur) { _, newValue in
            isBlurred = newValue
        }
        .onChange(of: post.id) { _, _ in
            isBlurred = shouldBlur
        }

        return Group {
            if let cornerRadius {
                blurred.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                blurred
            }
        }
    }
}

extension View {
    func sensitiveContentBlurred(post: RedditPost, contentType: SensitiveContentOverlay.ContentType, isBlurred: Binding<Bool>, cornerRadius: CGFloat? = 12) -> some View {
        modifier(SensitiveContentBlurModifier(post: post, contentType: contentType, isBlurred: isBlurred, cornerRadius: cornerRadius))
    }
}
