import SwiftUI
import Defaults

struct ContentView: View {
    @Default(.clientId) private var clientId
    @Default(.isSetupComplete) private var isSetupComplete
    @Default(.hasShownAPIDiscontinuationNotice) private var hasShownAPIDiscontinuationNotice
    @State private var apiService = RedditAPIManager()
    @State private var showingAPINotice = false

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
            if !hasShownAPIDiscontinuationNotice {
                showingAPINotice = true
            }
        }
        .alert("Mercury Development Update", isPresented: $showingAPINotice) {
            Button("I Understand") {
                hasShownAPIDiscontinuationNotice = true
            }
        } message: {
            Text("In late 2025, Reddit disabled the ability for new users to create API keys. Because of this, Mercury can no longer gain new users.\n\nExisting users can continue using the app normally, but active feature development has been discontinued. Minor bug fixes may still be released.\n\nThank you for using Mercury.")
        }
    }
}

#Preview {
    ContentView()
}
