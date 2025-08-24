import SwiftUI
import Defaults

struct MediaSettingsView: View {
    @Default(.blurNSFWContent) private var blurNSFWContent
    
    var body: some View {
        List {
            Section {
                Toggle("Blur NSFW Content", isOn: $blurNSFWContent)
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
