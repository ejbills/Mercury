//
//  EmbedCard.swift
//  Mercury
//
//  A shared compact embed card layout used for link previews
//  and Reddit post previews to ensure consistent styling.
//

import SwiftUI

struct EmbedCardMetrics {
    static let cornerRadius: CGFloat = 12
    static let thumbnailWidth: CGFloat = 100
    static let minHeight: CGFloat = 80
    static let contentPadding: CGFloat = 12
    static let contentSpacing: CGFloat = 4
}

struct EmbedCard<Thumbnail: View>: View {
    let thumbnail: Thumbnail
    let labelIcon: String
    let labelText: String
    let labelTint: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    init(
        thumbnail: Thumbnail,
        labelIcon: String,
        labelText: String,
        labelTint: Color,
        title: String,
        subtitle: String,
        onTap: @escaping () -> Void
    ) {
        self.thumbnail = thumbnail
        self.labelIcon = labelIcon
        self.labelText = labelText
        self.labelTint = labelTint
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: EmbedCardMetrics.contentSpacing) {
                HStack(spacing: 4) {
                    Image(systemName: labelIcon)
                        .font(.caption2)
                        .foregroundStyle(labelTint)
                    Text(labelText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(labelTint)
                        .lineLimit(1)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EmbedCardMetrics.contentPadding)

            thumbnail
                .frame(width: EmbedCardMetrics.thumbnailWidth)
                .frame(maxHeight: .infinity)
                .clipped()
        }
        .frame(minHeight: EmbedCardMetrics.minHeight)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EmbedCardMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EmbedCardMetrics.cornerRadius, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

