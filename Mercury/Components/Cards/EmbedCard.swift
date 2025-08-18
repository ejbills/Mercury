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
    static let thumbnailSize: CGFloat = 60
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 12
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
        HStack(spacing: 12) {
            thumbnail
                .frame(width: EmbedCardMetrics.thumbnailSize, height: EmbedCardMetrics.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: labelIcon)
                        .font(.caption)
                        .foregroundStyle(labelTint)
                    Text(labelText.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(labelTint)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 14)

                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: EmbedCardMetrics.thumbnailSize)
        }
        .padding(.horizontal, EmbedCardMetrics.horizontalPadding)
        .padding(.vertical, EmbedCardMetrics.verticalPadding)
        .background(
            Color(UIColor.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: EmbedCardMetrics.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EmbedCardMetrics.cornerRadius, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

