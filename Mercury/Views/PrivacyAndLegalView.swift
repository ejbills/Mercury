import SwiftUI

struct PrivacyAndLegalView: View {
    let apiService: RedditAPIManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MaterialCard {
                    SectionHeader(icon: "hand.raised.fill", title: "Data Collection")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mercury collects no analytics, tracking, or personal data — now or ever.")
                            .font(.body)
                        Text("All network requests go directly from your device to Reddit. There are no Mercury-operated servers in-between.")
                            .font(.body)
                        Text("Your Reddit OAuth credentials are stored on your device and used only to communicate with Reddit. You can remove them anytime by signing out in Settings.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.leading, 36)
                }

                MaterialCard {
                    SectionHeader(icon: "cup.and.saucer.fill", title: "Donations Only")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mercury is free to use. Donations are optional and appreciated, but never required.")
                            .font(.body)
                        Link(destination: URL(string: "https://buymeacoffee.com/keplercafe")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Buy me a coffee")
                            }
                        }
                    }
                    .padding(.leading, 36)
                }

                MaterialCard {
                    SectionHeader(icon: "info.circle.fill", title: "Affiliation")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mercury is an independent project and is not affiliated with, endorsed by, or sponsored by Reddit.")
                            .font(.body)
                        Text("Reddit and the Reddit logo are trademarks of their respective owners.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 36)
                }

                MaterialCard {
                    SectionHeader(icon: "key.fill", title: "API & Credentials")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mercury uses Reddit's OAuth flow and public endpoints. You provide your own Client ID created in your Reddit app preferences.")
                            .font(.body)
                        Text("You are responsible for how you use your Client ID and for complying with Reddit’s terms and policies for your account and application.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 36)
                }

                MaterialCard {
                    SectionHeader(icon: "exclamationmark.triangle.fill", title: "No Guarantees")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mercury is provided as-is, without warranties. If Reddit changes its policies or technical requirements, some features may stop working or become unavailable.")
                            .font(.body)
                        Text("If you ever want to stop using Mercury, use Settings → Manage Accounts → Swipe on your account → Remove to remove your local credentials.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 36)
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Privacy & Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyAndLegalView(apiService: RedditAPIManager())
    }
}

