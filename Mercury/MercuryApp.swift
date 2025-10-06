import SwiftUI
import Nuke
import AVFoundation
import Defaults

@main
struct MercuryApp: App {
    @Default(.appColorScheme) private var appColorScheme

    init() {
        // Configure Nuke pipeline once for the entire app
        ImagePipelineService.configureSharedPipeline()
        // Configure app-wide audio session so inline videos don't interrupt other audio
        AudioSessionManager.configureIfNeeded()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appColorScheme.colorScheme)
        }
        .handlesExternalEvents(matching: ["mercury"])
    }
}
