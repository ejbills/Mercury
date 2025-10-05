import SwiftUI
import Nuke
import NukeUI

struct RichArticleCard: View {
    let url: String
    let fallbackThumbnail: String?
    let fallbackDomain: String?
    let fallbackTitle: String?
    let onTap: () -> Void
    
    @State private var metadata: ArticleMetadata?
    @State private var isLoading = true
    
    var body: some View {
        EmbedCard(
            thumbnail: thumbnailView,
            labelIcon: "globe",
            labelText: displayDomain,
            labelTint: .secondary,
            title: displayTitle,
            subtitle: displayDescription,
            onTap: onTap
        )
        .task { await loadMetadata() }
    }
    
    // MARK: - Computed Properties for Stable Layout
    
    private var thumbnailView: some View {
        Group {
            if let imageURL = metadata?.imageURL ?? fallbackThumbnail {
                LazyImage(url: URL(string: imageURL)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        compactPlaceholder
                    }
                }
                .processors([.resize(size: CGSize(width: 200, height: 200))])
                .priority(.high)
                .transition(.opacity)
            } else {
                compactPlaceholder
            }
        }
    }
    
    private var displayDomain: String {
        metadata?.siteName ?? fallbackDomain ?? extractDomain(from: url)
    }
    
    private var displayTitle: String {
        metadata?.title ?? fallbackTitle ?? "Article"
    }
    
    private var displayDescription: String {
        if let description = metadata?.description, !description.isEmpty {
            return description
        } else if metadata?.title != nil {
            return "Tap to read the full article"
        } else {
            return "Loading preview..."
        }
    }
    
    private var compactPlaceholder: some View {
        Rectangle()
            .fill(.fill.secondary)
            .overlay {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }
    
    private func loadMetadata() async {
        Task.detached(priority: .utility) { [url] in
            let fetchedMetadata = await MetadataService.shared.fetchMetadata(for: url)
            
            if let fetchedMetadata = fetchedMetadata {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if self.metadata == nil {
                            self.metadata = fetchedMetadata
                            self.isLoading = false
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Website" }
        let host = url.host ?? "Website"
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

#Preview {
    RichArticleCard(
        url: "https://apple.com",
        fallbackThumbnail: nil,
        fallbackDomain: "apple.com",
        fallbackTitle: "Sample Article Title",
        onTap: {}
    )
    .padding()
}
