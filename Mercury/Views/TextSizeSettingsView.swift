import SwiftUI
import Defaults

struct TextSizeSettingsView: View {
    @Default(.titleTextScale) private var titleScale
    @Default(.bodyTextScale) private var bodyScale
    @Default(.captionTextScale) private var captionScale

    private let minScale: Double = 0.8
    private let maxScale: Double = 1.6

    var body: some View {
        List {
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Post Title Preview")
                        .appFont(.title, weight: .semibold)
                        .lineLimit(2)
                    Text("By u/someverylongusernamethatshouldtruncate in r/averylongsubredditname")
                        .appFont(.meta)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("Body text preview. This scales independently from iOS Accessibility sizes to prevent layout overflow.")
                        .appFont(.body)
                    Text("Caption preview")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Title Size") {
                HStack {
                    Slider(value: $titleScale, in: minScale...maxScale, step: 0.05)
                    Text(String(format: "%.0f%%", titleScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }

            Section("Body Size") {
                HStack {
                    Slider(value: $bodyScale, in: minScale...maxScale, step: 0.05)
                    Text(String(format: "%.0f%%", bodyScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }

            Section("Caption & Meta Size") {
                HStack {
                    Slider(value: $captionScale, in: minScale...maxScale, step: 0.05)
                    Text(String(format: "%.0f%%", captionScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }

            Section(footer:
                        Text("These sizes are applied within the app and do not modify your device's Accessibility text size settings.")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
            ) { EmptyView() }
        }
        .navigationTitle("Text Size")
    }
}

#Preview {
    NavigationStack { TextSizeSettingsView() }
}

