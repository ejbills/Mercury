import SwiftUI
import Nuke
import AVFoundation

@main
struct MercuryApp: App {
    init() {
        // Configure Nuke pipeline once for the entire app
        ImagePipelineService.configureSharedPipeline()
        // Configure app-wide audio session so inline videos don't interrupt other audio
        AudioSessionManager.configureIfNeeded()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .handlesExternalEvents(matching: ["mercury"])
    }
}
