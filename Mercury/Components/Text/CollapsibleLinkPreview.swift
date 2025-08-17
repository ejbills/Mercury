import SwiftUI
import LinkPresentation
import Nuke
import NukeUI

struct CollapsibleLinkPreview: View {
    let url: URL
    @State private var isExpanded = false
    @State private var metadata: LPLinkMetadata?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                        .frame(width: 16, height: 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metadata?.title ?? url.absoluteString)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        
                        Text(url.host ?? url.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Full link preview (expandable)
            if isExpanded {
                CompactLinkPreview(previewURL: url)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .task {
            await fetchBasicMetadata()
        }
    }
    
    private func fetchBasicMetadata() async {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            await MainActor.run {
                self.metadata = metadata
            }
        } catch {
            // Silently fail - will show URL as fallback
        }
    }
}

struct CompactLinkPreview: View {
    let previewURL: URL
    @State private var metadata: LPLinkMetadata?
    @State private var imageURL: URL?
    
    var body: some View {
        Button(action: {
            UIApplication.shared.open(previewURL)
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                Group {
                    if let imageURL = imageURL {
                        LazyImage(url: imageURL) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .clipped()
                            } else {
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    if let title = metadata?.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Text(previewURL.host ?? previewURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .task {
            await loadMetadata()
        }
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }
    
    private func loadMetadata() async {
        let provider = LPMetadataProvider()
        do {
            let fetchedMetadata = try await provider.startFetchingMetadata(for: previewURL)
            await MainActor.run {
                self.metadata = fetchedMetadata
                
                // Extract image URL from metadata
                if let imageProvider = fetchedMetadata.imageProvider {
                    Task {
                        do {
                            if let data = try await imageProvider.loadItem(forTypeIdentifier: "public.url", options: nil) as? Data,
                               let urlString = String(data: data, encoding: .utf8),
                               let url = URL(string: urlString) {
                                await MainActor.run {
                                    self.imageURL = url
                                }
                            }
                        } catch {
                            // Silently fail
                        }
                    }
                }
            }
        } catch {
            // Silently fail
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CollapsibleLinkPreview(url: URL(string: "https://www.apple.com")!)
        CollapsibleLinkPreview(url: URL(string: "https://github.com")!)
        CollapsibleLinkPreview(url: URL(string: "https://reddit.com")!)
    }
    .padding()
}
