import SwiftUI

struct MultiAccountView: View {
    @Environment(\.redditAPI) private var redditAPI
    @State private var switchingUsername: String? = nil
    @State private var error: String?
    @State private var newClientId: String = ""
    @State private var showingCopiedFeedback = false
    @State private var showingOAuthSheet = false

    var body: some View {
        Form {
            accountsSection
            addAccountSection
            quickLinksSection
            setupInstructionsSection
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't switch account", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "Unknown error")
        }
        .overlay(alignment: .top) {
            CopiedToast(isShowing: showingCopiedFeedback)
        }
    }

    // MARK: - Sections
    private var accountsSection: some View {
        Section {
            if redditAPI.storedAccounts.isEmpty {
                Text("No accounts added yet").foregroundStyle(.secondary)
            } else {
                ForEach(redditAPI.storedAccounts) { acct in
                    accountRow(acct)
                }
            }
        } header: {
            Text("Accounts")
        }
    }

    private var addAccountSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Client ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    PasteableTextField(
                        placeholder: "Enter your Reddit Client ID",
                        text: $newClientId
                    )
                }

                PrimaryButton(
                    "Authenticate Account",
                    icon: "person.badge.key",
                    isDisabled: newClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    redditAPI.startOAuthFlow(clientId: newClientId)
                }
                .padding(.top, 4)
            }
        } header: {
            Text("Add Account")
        } footer: {
            Text("Enter your Reddit app's Client ID and tap Authenticate. After authenticating, your account will appear in the list above.")
                .font(.footnote)
        }
    }

    private var quickLinksSection: some View {
        Section {
            Link(destination: URL(string: "https://www.reddit.com/register")!) {
                Label("Create a Reddit Account", systemImage: "person.badge.plus")
            }
            Link(destination: URL(string: "https://reddit.com/prefs/apps")!) {
                Label("Open Reddit Apps", systemImage: "link")
            }
        } header: {
            Text("Quick Links")
        } footer: {
            Text("To create a different Reddit account, you may need to sign out of Reddit in Safari manually before proceeding.")
                .font(.footnote)
        }
    }

    private var setupInstructionsSection: some View {
        Section {
            SetupInstructionsView(
                showingCopiedFeedback: $showingCopiedFeedback,
                clientId: .constant(""),
                showClientIdField: false
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        } header: {
            Text("Setup Instructions")
        }
    }

    // MARK: - Rows
    private func accountRow(_ acct: StoredAccount) -> some View {
        let activeName: String? = redditAPI.userInfo?.name ?? redditAPI.activeUsername
        let isActive = (activeName?.caseInsensitiveCompare(acct.username) == .orderedSame)
        let isSwitchingThis = switchingUsername?.caseInsensitiveCompare(acct.username) == .orderedSame

        // Check if this token is shared with another account
        let isDuplicate = redditAPI.storedAccounts.contains(where: {
            $0.refreshToken == acct.refreshToken && $0.username.caseInsensitiveCompare(acct.username) != .orderedSame
        })

        return Button {
            Task { await switchTo(acct.username) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(isDuplicate ? .orange : .blue)
                    Text(acct.username)
                    Spacer()
                    if isSwitchingThis {
                        ProgressView()
                    } else if isActive {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }

                if isDuplicate {
                    Text("Shares token with another account")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(isSwitchingThis)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                redditAPI.removeAccount(username: acct.username)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func switchTo(_ username: String) async {
        guard switchingUsername == nil else { return }
        switchingUsername = username
        defer { switchingUsername = nil }
        await redditAPI.switchToAccount(username: username)
    }
}
