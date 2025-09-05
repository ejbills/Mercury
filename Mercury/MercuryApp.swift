import SwiftUI
import Nuke

@main
struct MercuryApp: App {
    init() {
        // Configure Nuke pipeline once for the entire app
        ImagePipelineService.configureSharedPipeline()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .handlesExternalEvents(matching: ["mercury"])
    }
}
