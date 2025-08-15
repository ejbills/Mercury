//
//  ContentView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import Defaults

struct ContentView: View {
    @Default(.clientId) private var clientId
    @Default(.isSetupComplete) private var isSetupComplete
    @State private var apiService = RedditAPIManager()
    
    var body: some View {
        Group {
            if apiService.hasStoredCredentials && apiService.apiStatus == .valid {
                MainTabView(apiService: apiService)
            } else if isSetupComplete && !clientId.isEmpty {
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
        .environment(\.redditAPI, apiService)
        .onAppear {
            if apiService.hasStoredCredentials {
                Task {
                    await apiService.validateCredentials()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
