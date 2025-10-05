import SwiftUI
import Defaults

struct MediaSettingsView: View {
    @Default(.blurNSFWContent) private var blurNSFWContent
    @Default(.blurSpoilerContent) private var blurSpoilerContent
    
    var body: some View {
        List {
            Section {
                Toggle("Blur NSFW Content", isOn: $blurNSFWContent)
                Toggle("Blur Spoiler Content", isOn: $blurSpoilerContent)
            } header: {
                Text("Content Settings")
            }
        }
        .navigationTitle("Media Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        MediaSettingsView()
    }
}
