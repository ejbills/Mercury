//
//  ContentView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct ContentView: View {
    @State private var clientId: String = ""
    @State private var isSetupComplete: Bool = false
    @State private var apiService = RedditAPIService()
    
    var body: some View {
        Group {
            if isSetupComplete && !clientId.isEmpty {
                APIStatusView(
                    clientId: $clientId,
                    isSetupComplete: $isSetupComplete,
                    apiService: apiService
                )
            } else {
                OAuthSetupView(
                    clientId: $clientId,
                    isSetupComplete: $isSetupComplete,
                    apiService: apiService
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
