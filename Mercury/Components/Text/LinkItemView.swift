import SwiftUI
import LinkPresentation

struct LinkItemView: View {
    let link: String
    
    @State private var metadata: LPLinkMetadata?
    @State private var imageStatus: ImageStatus = .loading
    @Environment(\.colorScheme) private var colorScheme
    
    private var url: URL? {
        URL(string: link)
    }
    
    private var isValidUrl: Bool {
        url != nil
    }
    
    private var isRedditSubreddit: Bool {
        link.hasPrefix("r/") || link.contains("/r/")
    }
    
    private var isRedditUser: Bool {
        link.hasPrefix("u/") || link.contains("/u/")
    }
    
    var body: some View {
        Group {
            if isRedditSubreddit {
                redditSubredditView
            } else if isRedditUser {
                redditUserView
            } else if isValidUrl, let url {
                Link(destination: url) {
                    linkCard
                }
                .buttonStyle(LinkCardButtonStyle())
            } else {
                invalidURLView
            }
        }
        .task(id: url) {
            if !isRedditSubreddit && !isRedditUser {
                await fetchMetadata()
            }
        }
    }
    
    private var linkCard: some View {
        HStack(spacing: 12) {
            // Thumbnail with modern styling
            thumbnailView
            
            // Content with proper hierarchy
            VStack(alignment: .leading, spacing: 4) {
                titleView
                domainView
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Subtle chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorder, lineWidth: 0.33)
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var thumbnailView: some View {
        Group {
            switch imageStatus {
            case .loading:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                    }
                
            case .finished(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()
                
            case .failed:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 60, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .opacity(0.5)
        )
    }
    
    private var titleView: some View {
        Text(metadata?.title ?? url?.host ?? url?.absoluteString ?? "Loading...")
            .font(.system(.subheadline, design: .default, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .redacted(reason: metadata == nil ? .placeholder : [])
            .animation(.easeInOut(duration: 0.3), value: metadata?.title)
    }
    
    private var domainView: some View {
        Group {
            if metadata != nil {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(metadata?.url?.host ?? url?.host ?? "Unknown domain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(url?.host ?? "Unknown domain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var invalidURLView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            
            Text("Invalid URL")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var redditSubredditView: some View {
        Button(action: {
            // TODO: Navigate to subreddit
        }) {
            HStack(spacing: 8) {
                Image(systemName: "r.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)
                
                Text(extractRedditName(from: link, prefix: "r/"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var redditUserView: some View {
        Button(action: {
            // TODO: Navigate to user profile
        }) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text(extractRedditName(from: link, prefix: "u/"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func extractRedditName(from text: String, prefix: String) -> String {
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        } else if let range = text.range(of: "/\(prefix)") {
            let afterPrefix = text[range.upperBound...]
            if let spaceRange = afterPrefix.range(of: " ") {
                return String(afterPrefix[..<spaceRange.lowerBound])
            } else {
                return String(afterPrefix)
            }
        }
        return text
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? 
            Color(UIColor.secondarySystemGroupedBackground) : 
            Color(UIColor.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? 
            Color(UIColor.separator).opacity(0.3) : 
            Color(UIColor.separator).opacity(0.2)
    }
}

// MARK: - Button Style
struct LinkCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Private Methods
extension LinkItemView {
    private func fetchMetadata() async {
        guard let url = url else { return }
        
        let provider = LPMetadataProvider()
        do {
            let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
            await MainActor.run {
                self.metadata = fetchedMetadata
            }
            await loadImage(from: fetchedMetadata.imageProvider)
        } catch {
            await MainActor.run {
                self.imageStatus = .failed
            }
        }
    }
    
    private func loadImage(from provider: NSItemProvider?) async {
        guard let provider = provider else {
            await MainActor.run {
                self.imageStatus = .failed
            }
            return
        }
        
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { (image, error) in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self.imageStatus = .finished(Image(uiImage: image))
                    } else {
                        self.imageStatus = .failed
                    }
                }
            }
        } else {
            await MainActor.run {
                self.imageStatus = .failed
            }
        }
    }
}

enum ImageStatus {
    case loading
    case finished(Image)
    case failed
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            LinkItemView(link: "https://www.apple.com")
            LinkItemView(link: "https://github.com")
            LinkItemView(link: "https://www.reddit.com")
            LinkItemView(link: "invalid-url")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    .background(Color(UIColor.systemGroupedBackground))
}