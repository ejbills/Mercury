import SwiftUI

@main
struct MercuryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .handlesExternalEvents(matching: ["mercury"])
    }
}
