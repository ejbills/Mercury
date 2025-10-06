import SwiftUI
import Defaults

struct TextSizeSettingsView: View {
    // Persisted scales
    @Default(.titleTextScale) private var titleScale
    @Default(.bodyTextScale) private var bodyScale
    @Default(.captionTextScale) private var captionScale

    // Live preview scales (decoupled while dragging)
    @State private var previewTitleScale: Double = Defaults[.titleTextScale]
    @State private var previewBodyScale: Double = Defaults[.bodyTextScale]
    @State private var previewCaptionScale: Double = Defaults[.captionTextScale]

    // Wider range per request
    private let minScale: Double = 0.5
    private let maxScale: Double = 2.5

    var body: some View {
        List {
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Post Title Preview")
                        .font(.system(size: 16 * previewTitleScale, weight: .semibold))
                        .lineLimit(2)
                    Text("By u/someverylongusernamethatshouldtruncate in r/averylongsubredditname")
                        .font(.system(size: 12 * previewCaptionScale))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("The quick brown fox jumped over the lazy dog.")
                        .font(.system(size: 16 * previewBodyScale))
                }
                .padding(.vertical, 8)
                .frame(height: 220) // lock layout so sliders don't shift while dragging
            }

            Section("Title Size") {
                HStack {
                    Slider(value: $previewTitleScale, in: minScale...maxScale, step: 0.01, onEditingChanged: { editing in
                        if !editing { titleScale = previewTitleScale }
                    })
                    Text(String(format: "%.0f%%", previewTitleScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }

            Section("Body Size") {
                HStack {
                    Slider(value: $previewBodyScale, in: minScale...maxScale, step: 0.01, onEditingChanged: { editing in
                        if !editing { bodyScale = previewBodyScale }
                    })
                    Text(String(format: "%.0f%%", previewBodyScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }

            Section("Caption & Meta Size") {
                HStack {
                    Slider(value: $previewCaptionScale, in: minScale...maxScale, step: 0.01, onEditingChanged: { editing in
                        if !editing { captionScale = previewCaptionScale }
                    })
                    Text(String(format: "%.0f%%", previewCaptionScale * 100))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .appFont(.caption)
                }
            }
        }
        .navigationTitle("Text Size")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") { resetScales() }
            }
        }
    }

    private func resetScales() {
        withAnimation(.easeInOut(duration: 0.15)) {
            previewTitleScale = 1.0
            previewBodyScale = 1.0
            previewCaptionScale = 1.0
            titleScale = 1.0
            bodyScale = 1.0
            captionScale = 1.0
        }
    }
}

#Preview {
    NavigationStack { TextSizeSettingsView() }
}
