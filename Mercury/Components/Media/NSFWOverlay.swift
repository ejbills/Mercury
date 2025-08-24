import SwiftUI
import Defaults

struct NSFWOverlay: View {
    let post: RedditPost
    let contentType: ContentType
    @Binding var isBlurred: Bool
    @Default(.blurNSFWContent) private var blurNSFWContent
    
    enum ContentType {
        case image
        case video
        case gif
        case gallery
        
        var overlayText: String {
            switch self {
            case .image:
                return "NSFW Content"
            case .video:
                return "NSFW Content"
            case .gif:
                return "NSFW Content"
            case .gallery:
                return "NSFW Gallery"
            }
        }
    }
    
    var shouldShow: Bool {
        return post.isNsfw && blurNSFWContent && isBlurred
    }
    
    var body: some View {
        if shouldShow {
            ZStack {
                Color.black.opacity(0.7)
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(contentType.overlayText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Tap to reveal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

extension View {
    func nsfwBlurred(post: RedditPost, contentType: NSFWOverlay.ContentType, isBlurred: Binding<Bool>) -> some View {
        ZStack {
            self
                .blur(radius: (post.isNsfw && Defaults[.blurNSFWContent] && isBlurred.wrappedValue) ? 20 : 0)
            
            NSFWOverlay(post: post, contentType: contentType, isBlurred: isBlurred)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            isBlurred.wrappedValue = post.isNsfw && Defaults[.blurNSFWContent]
        }
    }
}