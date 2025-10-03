import SwiftUI

struct MultiAccountSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.redditAPI) private var redditAPI
    @State private var isSwitching = false
    @State private var error: String?
    @State private var newClientId: String = ""
    @State private var showingCopiedFeedback = false

    var body: some View {
        NavigationStack {
            Form {
                accountsSection
                addAccountSection
                quickLinksSection
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .alert("Couldn't switch account", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "Unknown error")
            }
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
            PasteableTextField(
                placeholder: "Enter your Reddit Client ID",
                text: $newClientId
            )

            CopyableField(label: "Redirect URI", value: "mercury://oauth", showingCopied: $showingCopiedFeedback)

            if let url = (newClientId.isEmpty ? nil : redditAPI.buildAuthorizationURL(for: newClientId)) {
                VStack(alignment: .leading, spacing: 8) {
                    CopyableField(label: "Authorization URL", value: url.absoluteString, showingCopied: $showingCopiedFeedback)
                }
            }

            Button {
                redditAPI.startOAuthFlow(clientId: newClientId)
            } label: {
                Label("Open OAuth Popup", systemImage: "rectangle.on.rectangle")
            }
            .disabled(newClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("Add Account")
        } footer: {
            Text("After authenticating, your account will appear in the list above.")
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
            Text("Refer to the OAuth setup steps for Client ID and redirect URI guidance.")
        }
    }

    // MARK: - Rows
    private func accountRow(_ acct: StoredAccount) -> some View {
        let activeName: String? = redditAPI.userInfo?.name ?? redditAPI.activeUsername
        let isActive = (activeName?.caseInsensitiveCompare(acct.username) == .orderedSame)
        return HStack {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.blue)
            Text(acct.username)
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await switchTo(acct.username) } }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                redditAPI.removeAccount(username: acct.username)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func switchTo(_ username: String) async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }
        await redditAPI.switchToAccount(username: username)
        await MainActor.run { isPresented = false }
    }
}
