//
//  RichArticleCard.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

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
        HStack(spacing: 12) {
            // Compact thumbnail on left - ALWAYS fixed size with proper rounding
            thumbnailView
                .frame(width: 80, height: 80) // Fixed size prevents layout shift
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Match regular image posts corner radius
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            
            // Content section - ALWAYS same height
            VStack(alignment: .leading, spacing: 6) {
                // Site name and external link indicator
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text(displayDomain.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 16) // Fixed height
                
                // Article title - ALWAYS 2 lines reserved
                Text(displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(metadata?.title != nil ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 40) // Reserve space for 2 lines
                
                // Article description - ALWAYS 1 line reserved
                Text(displayDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 16) // Fixed single line height
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80) // Match thumbnail height for consistency
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await loadMetadata()
        }
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
                            .frame(width: 80, height: 80)
                            .clipped() // Ensure it's clipped to the frame
                    } else {
                        compactPlaceholder
                    }
                }
                .processors([.resize(size: CGSize(width: 160, height: 160))]) // Smaller resize for thumbnails
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
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }
    
    private func loadMetadata() async {
        // Load metadata completely in background to prevent UI stuttering
        Task.detached(priority: .utility) { [url] in
            let fetchedMetadata = await MetadataService.shared.fetchMetadata(for: url)
            
            // Only update UI if we successfully got metadata and still need it
            if let fetchedMetadata = fetchedMetadata {
                await MainActor.run {
                    // Use a smooth animation to prevent jarring updates
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
