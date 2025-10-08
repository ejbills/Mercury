import SwiftUI
import MarkdownUI
import PhotosUI
import UIKit

struct PostComposerSheet: View {
    let initialSubreddit: String
    let onSubmitted: (() -> Void)?

    @Environment(\.redditAPI) private var redditAPI
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubreddit: String = ""
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var selectedRange: NSRange = .init(location: 0, length: 0)
    @State private var isFirstResponder: Bool = true
    @State private var mode: Mode = .write
    @State private var postType: PostType = .text
    @State private var linkURL: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isSubmitting = false
    @State private var selectedAccount: String = ""
    @State private var errorMessage: String?
    @State private var flairErrorMessage: String?
    @State private var flairs: [LinkFlair] = []
    @State private var selectedFlairId: String? = nil
    @State private var isFlairRequired: Bool = false
    @State private var isLoadingFlairs = false

    private enum Mode: String, CaseIterable, Identifiable { case write, preview; var id: String { rawValue } }

    enum PostType: String, CaseIterable, Identifiable { case text, link, image; var id: String { rawValue } }

    private var accounts: [String] {
        availableAccounts
    }

    private var accountSection: some View {
        Section(header: Text("Posting As")) {
            if accounts.isEmpty {
                Text("Add an account in Settings to post.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Account", selection: Binding(
                    get: {
                        // Ensure selection is always valid
                        if selectedAccount.isEmpty || !accounts.contains(selectedAccount) {
                            return accounts.first ?? ""
                        }
                        return selectedAccount
                    },
                    set: { selectedAccount = $0 }
                )) {
                    ForEach(accounts, id: \.self) { username in
                        Text("u/\(username)")
                            .tag(username)
                    }
                }
                .lineLimit(1)
                .pickerStyle(.menu)
            }
        }
    }

    private var subredditSection: some View {
        Section(header: Text("Subreddit")) {
            HStack(spacing: 8) {
                TextField("r/subreddit", text: $selectedSubreddit)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if isLoadingFlairs {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: { Task { await loadFlairsIfNeeded(force: true) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(selectedSubreddit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Fetch flairs for this subreddit")
                }
            }
        }
    }

    private var typeSection: some View {
        Section(header: Text("Type")) {
            Picker("Type", selection: $postType) {
                Text("Text").tag(PostType.text)
                Text("Link").tag(PostType.link)
                Text("Image").tag(PostType.image)
            }
            .pickerStyle(.segmented)
        }
    }

    private var titleSection: some View {
        Section(header: Text("Title")) {
            TextField("Post title", text: $title)
                .textInputAutocapitalization(.sentences)
        }
    }

    private var flairSection: some View {
        Section(header: Text("Flair")) {
            if let flairError = flairErrorMessage {
                Text(flairError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if !flairs.isEmpty {
                Picker("Flair", selection: Binding(
                    get: { selectedFlairId ?? "" },
                    set: { v in selectedFlairId = v.isEmpty ? nil : v }
                )) {
                    Text("None").tag("")
                    ForEach(flairs, id: \.id) { flair in
                        Text(flair.text).tag(flair.id)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text(isFlairRequired ? "Flair required. Tap the refresh icon to load flairs." : "No flairs available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isFlairRequired && selectedFlairId == nil {
                Text("This subreddit requires a post flair.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var linkURLSection: some View {
        Section(header: Text("Link URL")) {
            TextField("https://example.com", text: $linkURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
    }

    private var bodySection: some View {
        Section(header: Text(postType == .text ? "Body (optional)" : "Caption (optional)")) {
            VStack(spacing: 0) {
                modeSwitcher
                markdownToolbar
                editorOrPreview
                if postType == .image {
                    imageCounter
                }
            }
        }
    }

    private var modeSwitcher: some View {
        HStack {
            Picker("Mode", selection: $mode) {
                Text("Write").tag(Mode.write)
                Text("Preview").tag(Mode.preview)
            }
            .pickerStyle(.segmented)
        }
        .padding(.bottom, 8)
    }

    private var markdownToolbar: some View {
        MarkdownToolsBar(
            onH1: { insertAtLineStart("# ") },
            onH2: { insertAtLineStart("## ") },
            onH3: { insertAtLineStart("### ") },
            onBold: { wrap("**") },
            onItalic: { wrap("*") },
            onStrike: { wrap("~~") },
            onCode: { wrap("`") },
            onBlock: { wrapBlockFence() },
            onQuote: { prefixLines("> ") },
            onUL: { prefixLines("- ") },
            onOL: { prefixLinesNumbered() },
            onLink: { insertLink() },
            onHR: { insert("\n\n---\n\n") }
        )
    }

    private var editorOrPreview: some View {
        Group {
            if mode == .preview {
                previewContent
            } else {
                editorContent
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var previewContent: some View {
        ScrollView {
            if postType == .image {
                if !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownRenderer(content: bodyText, compactMode: false, showEmbeddedContent: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                }
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                MarkdownRenderer(content: bodyText, compactMode: false, showEmbeddedContent: true)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            }
        }
    }

    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            MarkdownTextView(text: $bodyText, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                .frame(minHeight: 200, alignment: .topLeading)
            if bodyText.isEmpty {
                Text(postType == .image ? "Write an optional caption in Markdown…" : "Write your post in Markdown…")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var imageCounter: some View {
        Group {
            Divider().padding(.vertical, 6)
            let count = selectedImages.count
            Text(count == 0 ? "No images attached" : "\(count) image\(count == 1 ? "" : "s") attached")
                .font(.footnote)
                .foregroundStyle(count == 0 ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                subredditSection
                typeSection
                titleSection
                flairSection
                if postType == .link {
                    linkURLSection
                }
                if postType != .link {
                    bodySection
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if postType == .image {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        .accessibilityLabel("Attach Images")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await submit() } }) {
                        if isSubmitting { ProgressView() } else { Text("Post") }
                    }
                    .disabled(isSubmitting ||
                              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              (postType == .link && linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                              (postType == .image && selectedImages.isEmpty) ||
                              (isFlairRequired && selectedFlairId == nil))
                }
            }
            .task {
                if selectedAccount.isEmpty, let first = availableAccounts.first {
                    selectedAccount = first
                }
                // Prefill only if a concrete subreddit was provided; otherwise leave empty placeholder
                if initialSubreddit.lowercased().hasPrefix("r/") {
                    selectedSubreddit = initialSubreddit
                } else {
                    selectedSubreddit = ""
                }
                await loadFlairsIfNeeded(force: false)
            }
            .alert("Couldn't submit post", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "Unknown error") }
        }
        .onChange(of: photoItems) { _, newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems.prefix(20) {
                    if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                        images.append(ui)
                    }
                }
                await MainActor.run {
                    self.selectedImages = Array(images.prefix(20))
                }
            }
        }
        .onChange(of: selectedSubreddit) { _, _ in
            Task { await loadFlairsIfNeeded(force: false) }
        }
        .onChange(of: selectedAccount) { _, _ in
            Task { await loadFlairsIfNeeded(force: true) }
        }
    }

    // MARK: - Editing helpers (inline for now)
    // MARK: - Editing helpers (inline for now)
    private func insert(_ snippet: String) {
        let ns = bodyText as NSString
        let loc = max(0, min(selectedRange.location, ns.length))
        bodyText = ns.replacingCharacters(in: NSRange(location: loc, length: 0), with: snippet)
        selectedRange = NSRange(location: loc + (snippet as NSString).length, length: 0)
    }
    private func wrap(_ token: String) {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        let selected = ns.substring(with: range)
        let replacement = token + selected + token
        bodyText = ns.replacingCharacters(in: range, with: replacement)
        selectedRange = NSRange(location: range.location + token.count + selected.count, length: 0)
    }
    private func wrapBlockFence() {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        let selected = ns.substring(with: range)
        if selected.isEmpty {
            let replacement = "\n```\n\n```\n"
            bodyText = ns.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(location: range.location + 5, length: 0)
        } else {
            let replacement = "\n```\n" + selected + "\n```\n"
            bodyText = ns.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(location: range.location + replacement.count, length: 0)
        }
    }
    private func insertAtLineStart(_ token: String) {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
        let newText = ns.replacingCharacters(in: NSRange(location: lineStart, length: 0), with: token)
        bodyText = newText
        let delta = (token as NSString).length
        if range.length == 0 {
            selectedRange = NSRange(location: range.location + delta, length: 0)
        } else {
            selectedRange = NSRange(location: range.location + delta, length: range.length)
        }
    }
    private func prefixLines(_ token: String) {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        let linesRange = ns.lineRange(for: range)
        let substring = ns.substring(with: linesRange)
        let prefixed = substring.split(separator: "\n", omittingEmptySubsequences: false).map { token + $0 }.joined(separator: "\n")
        bodyText = ns.replacingCharacters(in: linesRange, with: prefixed)
        selectedRange = NSRange(location: linesRange.location, length: (prefixed as NSString).length)
    }
    private func prefixLinesNumbered() {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        let linesRange = ns.lineRange(for: range)
        let substring = ns.substring(with: linesRange)
        let lines = substring.split(separator: "\n", omittingEmptySubsequences: false)
        let numbered = lines.enumerated().map { "\($0.offset + 1). " + $0.element }.joined(separator: "\n")
        bodyText = ns.replacingCharacters(in: linesRange, with: numbered)
        selectedRange = NSRange(location: linesRange.location, length: (numbered as NSString).length)
    }
    private func insertLink() {
        let ns = bodyText as NSString
        let range = clampedRange(selectedRange, in: ns)
        if range.length > 0 {
            let selected = ns.substring(with: range)
            let replacement = "[\(selected)](https://)"
            bodyText = ns.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(location: range.location + replacement.count - 1 - "https://)".count, length: 0)
        } else {
            let snippet = "[title](https://)"
            bodyText = ns.replacingCharacters(in: NSRange(location: range.location, length: 0), with: snippet)
            selectedRange = NSRange(location: range.location + 1, length: 5)
        }
    }
    private func clampedRange(_ range: NSRange, in ns: NSString) -> NSRange {
        let loc = max(0, min(range.location, ns.length))
        let len = max(0, min(range.length, ns.length - loc))
        return NSRange(location: loc, length: len)
    }

    private var availableAccounts: [String] {
        redditAPI.availableAccountUsernames()
    }

    private func resolvedPostingAccount() -> String? {
        let trimmed = selectedAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return availableAccounts.first
    }

    private func submit() async {
        guard !isSubmitting else { return }
        let trimmedSub = selectedSubreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSub.isEmpty else {
            await MainActor.run { errorMessage = "Please enter a subreddit (e.g. r/Swift)" }
            return
        }
        guard let account = resolvedPostingAccount() else {
            await MainActor.run { errorMessage = "Select an account before posting." }
            return
        }
        isSubmitting = true
        do {
            let clean = trimmedSub.hasPrefix("r/") ? String(trimmedSub.dropFirst(2)) : trimmedSub
            print("[Composer] submit subreddit=\(clean) postType=\(postType) flairId=\(selectedFlairId ?? "<none>")")
            try await redditAPI.performUsingAccount(username: account) {
                switch postType {
                case .text:
                    try await redditAPI.submitTextPost(subreddit: clean, title: title, text: bodyText, flairId: selectedFlairId)
                case .link:
                    try await redditAPI.submitLinkPost(subreddit: clean, title: title, url: linkURL, flairId: selectedFlairId)
                case .image:
                    try await redditAPI.submitImagePost(subreddit: clean, title: title, caption: bodyText.isEmpty ? nil : bodyText, images: selectedImages, flairId: selectedFlairId)
                }
            }
            isSubmitting = false
            let h = UINotificationFeedbackGenerator()
            h.notificationOccurred(.success)
            onSubmitted?()
            dismiss()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func loadFlairsIfNeeded(force: Bool) async {
        let sub = selectedSubreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else {
            await MainActor.run {
                flairs = []
                selectedFlairId = nil
                isFlairRequired = false
                flairErrorMessage = nil
            }
            return
        }
        if !force && !flairs.isEmpty { return }

        await MainActor.run { isLoadingFlairs = true }
        defer { Task { await MainActor.run { isLoadingFlairs = false } } }

        guard let account = resolvedPostingAccount() else {
            await MainActor.run {
                flairs = []
                selectedFlairId = nil
                isFlairRequired = false
                flairErrorMessage = "Select an account before loading flairs."
            }
            return
        }

        print("[Composer] loadFlairsIfNeeded(force=\(force)) subreddit=\(sub) account=\(account)")

        do {
            let clean = sub.hasPrefix("r/") ? String(sub.dropFirst(2)) : sub
            let result = try await redditAPI.performUsingAccount(username: account) { () async throws -> ([LinkFlair], PostRequirements?) in
                async let flairTask: [LinkFlair] = try redditAPI.fetchLinkFlairs(subreddit: clean)
                let postTypeKey: String = {
                    switch postType {
                    case .text: return "self"
                    case .link: return "link"
                    case .image: return "image"
                    }
                }()
                async let requirementsTask: PostRequirements? = try redditAPI.fetchPostRequirements(subreddit: clean, postType: postTypeKey)
                return try await (flairTask, requirementsTask)
            }

            var (list, requirements) = result
            list = list.filter { ($0.modOnly ?? false) == false }

            await MainActor.run {
                self.flairs = list
                self.isFlairRequired = requirements?.isFlairRequired ?? false
                self.flairErrorMessage = nil

                if let current = self.selectedFlairId, !list.contains(where: { $0.id == current }) {
                    self.selectedFlairId = nil
                }
            }
        } catch {
            print("[Composer] flair fetch error=\(error.localizedDescription)")
            await MainActor.run {
                flairs = []
                isFlairRequired = false
                selectedFlairId = nil
                flairErrorMessage = error.localizedDescription
            }
        }
    }
}
