import SwiftUI
import NukeUI

struct MultiRedditRow: View {
    let multi: MultiReddit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let url = multi.iconURL {
                        LazyImage(url: url) { state in
                            if let image = state.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { multiIconPlaceholder }
                        }
                    } else {
                        multiIconPlaceholder
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("m/\(multi.displayName)")
                        .appFont(.body, weight: .medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(multi.subreddits.count) subreddits")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var multiIconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
