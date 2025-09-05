import SwiftUI
import Defaults

struct SettingsView: View {
    let apiService: RedditAPIManager
    @Default(.clientId) private var clientId
    @Default(.isSetupComplete) private var isSetupComplete
    @State private var showingSignOutConfirm = false

    var body: some View {
        List {
            Section("Account") {
                if let user = apiService.userInfo {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.gradient)
                                .frame(width: 40, height: 40)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("u/\(user.name)")
                                .font(.headline)
                            Text("\(user.totalKarma.formatted()) karma")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
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
                } else {
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showingSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("Preferences") {
                NavigationLink {
                    FilterSettingsView()
                } label: {
                    Label("Content Filters", systemImage: "line.3.horizontal.decrease.circle")
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
        .alert("Sign Out?", isPresented: $showingSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                apiService.clearStoredCredentials()
            }
        } message: {
            Text("You’ll need to reauthenticate to continue using Mercury.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(apiService: RedditAPIManager())
    }
}
