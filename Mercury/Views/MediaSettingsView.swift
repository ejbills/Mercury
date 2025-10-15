import SwiftUI
import Defaults

struct MediaSettingsView: View {
    @Default(.blurNSFWContent) private var blurNSFWContent
    @Default(.blurSpoilerContent) private var blurSpoilerContent
    @Default(.readPostIds) private var readPostIds
    @Default(.hideReadPosts) private var hideReadPosts

    var body: some View {
        List {
            Section {
                Toggle("Blur NSFW Content", isOn: $blurNSFWContent)
                Toggle("Blur Spoiler Content", isOn: $blurSpoilerContent)
            } header: {
                Text("Content Settings")
            }

            Section {
                Toggle("Hide Read Posts", isOn: $hideReadPosts)

                if readPostIds.isEmpty {
                    Text("No read posts")
                        .foregroundColor(.secondary)
                } else {
                    Button("Clear All Read Posts") {
                        readPostIds.removeAll()
                    }
                    .foregroundColor(.red)
                }
            } header: {
                HStack {
                    Text("Read Posts")
                    Spacer()
                    Text("(\(readPostIds.count))")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("Posts are marked as read when you tap to view them. Enable 'Hide Read Posts' to filter them from your feed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Behavior")
    }
}

#Preview {
    NavigationStack {
        MediaSettingsView()
    }
}
