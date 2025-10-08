import SwiftUI
import Defaults

struct SettingsView: View {
    let apiService: RedditAPIManager
    @Default(.clientId) private var clientId
    @Default(.isSetupComplete) private var isSetupComplete

    var body: some View {
        List {
            Section("Account") {
                NavigationLink {
                    MultiAccountView()
                        .environment(\.redditAPI, apiService)
                } label: {
                    HStack {
                        Label("Manage Accounts", systemImage: "person.2.circle")
                        Spacer()
                        if let name = apiService.userInfo?.name ?? apiService.activeUsername {
                            Text("u/\(name)").foregroundStyle(.secondary)
                        }
                    }
                }

                Link(destination: URL(string: "https://buymeacoffee.com/keplercafe")!) {
                    HStack {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Preferences") {
                NavigationLink {
                    FilterSettingsView()
                } label: {
                    Label("Content Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance", systemImage: "paintbrush")
                }
                
                NavigationLink {
                    TextSizeSettingsView()
                } label: {
                    Label("Text Size", systemImage: "textformat.size")
                }

                NavigationLink {
                    MediaSettingsView()
                } label: {
                    Label("Media Settings", systemImage: "photo.on.rectangle.angled")
                }
                
                NavigationLink {
                    SwipeActionsSettingsView()
                } label: {
                    Label("Swipe Actions", systemImage: "hand.point.up.left")
                }
            }

            Section("Configuration") {
                NavigationLink {
                    APIStatusView(
                        clientId: $clientId,
                        isSetupComplete: $isSetupComplete,
                        apiService: apiService
                    )
                } label: {
                    Label("Reddit API Status", systemImage: "checkmark.shield")
                }

                NavigationLink {
                    ProxySettingsView()
                } label: {
                    Label("Network & Proxy", systemImage: "network")
                }
            }

            Section("Privacy & Legal") {
                NavigationLink {
                    PrivacyAndLegalView(apiService: apiService)
                } label: {
                    Label("Privacy, Terms, and Disclaimers", systemImage: "lock.shield")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView(apiService: RedditAPIManager())
    }
}
