import SwiftUI
import Defaults

struct SettingsView: View {
    let apiService: RedditAPIManager
    @Default(.clientId) private var clientId
    @Default(.isSetupComplete) private var isSetupComplete
    @State private var showingSignOutConfirm = false
    @State private var showingAccounts = false

    var body: some View {
        List {
            Section("Account") {
                Button {
                    showingAccounts = true
                } label: {
                    HStack {
                        Label("Manage Accounts", systemImage: "person.2.circle")
                        Spacer()
                        if let name = apiService.userInfo?.name ?? apiService.activeUsername {
                            Text("u/\(name)").foregroundStyle(.secondary)
                        }
                    }
                }

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
                } else if apiService.activeUsername == nil {
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                }

                if let currentName = apiService.userInfo?.name ?? apiService.activeUsername {
                    Button(role: .destructive) {
                        showingSignOutConfirm = true
                    } label: {
                        Label("Sign out u/\(currentName)", systemImage: "rectangle.portrait.and.arrow.right")
                    }
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
        .alert("Sign Out?", isPresented: $showingSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                if let name = apiService.userInfo?.name ?? apiService.activeUsername {
                    apiService.removeAccount(username: name)
                }
            }
        } message: {
            Text("You’ll be signed out of u/\(apiService.userInfo?.name ?? apiService.activeUsername ?? "-"). You can add or sign in again anytime.")
        }
        .sheet(isPresented: $showingAccounts) {
            MultiAccountSheet(isPresented: $showingAccounts)
                .environment(\.redditAPI, apiService)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(apiService: RedditAPIManager())
    }
}
