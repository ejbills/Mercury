//
//  MercuryApp.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

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
