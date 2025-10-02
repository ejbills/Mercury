import SwiftUI
import Defaults

struct MultiEditorView: View {
    enum Mode { case create, edit(existing: MultiReddit) }

    let mode: Mode
    let apiService: RedditAPIManager
    let availableSubreddits: [Subreddit]
    let onComplete: (MultiReddit?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var descriptionMd: String = ""
    @State private var selectedSubs: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""

    init(mode: Mode, apiService: RedditAPIManager, availableSubreddits: [Subreddit], onComplete: @escaping (MultiReddit?) -> Void) {
        self.mode = mode
        self.apiService = apiService
        self.availableSubreddits = availableSubreddits
        self.onComplete = onComplete
        switch mode {
        case .create:
            break
        case .edit(let existing):
            _name = State(initialValue: existing.name)
            _descriptionMd = State(initialValue: existing.descriptionMd ?? "")
            _selectedSubs = State(initialValue: Set(existing.subreddits))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                detailsSection
                subredditsSection
            }
            .searchable(text: $searchText)
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await save() } }) {
                        Text(isSaving ? "Saving…" : "Save")
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Error", isPresented: errorAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            TextField("Description (optional)", text: $descriptionMd, axis: .vertical)
        }
    }

    private var subredditsSection: some View {
        Section("Subreddits") {
            SwiftUI.ForEach(filteredSubs, id: \.id) { (subreddit: Subreddit) in
                HStack {
                    Text(subreddit.displayNamePrefixed)
                        .appFont(.body)
                        .lineLimit(1)
                    Spacer()
                    if selectedSubs.contains(subreddit.displayName) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    let name = subreddit.displayName
                    if selectedSubs.contains(name) { selectedSubs.remove(name) }
                    else { selectedSubs.insert(name) }
                }
            }
        }
    }

    var filteredSubs: [Subreddit] {
        let base = availableSubreddits
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.displayName.localizedCaseInsensitiveContains(q) || $0.title.localizedCaseInsensitiveContains(q) }
    }

    private var modeTitle: String {
        switch mode { case .create: return "New Multireddit"; case .edit: return "Edit Multireddit" }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedSubs.isEmpty }

    private var errorAlertPresented: Binding<Bool> {
        Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        do {
            switch mode {
            case .create:
                let created = try await apiService.createMultireddit(displayName: name, subreddits: Array(selectedSubs), descriptionMd: descriptionMd.isEmpty ? nil : descriptionMd)
                onComplete(created)
            case .edit(let existing):
                let username = apiService.userInfo?.name ?? "me"
                let updated = try await apiService.updateMultireddit(username: username, name: existing.name, displayName: name, subreddits: Array(selectedSubs), descriptionMd: descriptionMd)
                onComplete(updated)
            }
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}
