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
    @State private var errorMessage: String?
    @State private var flairs: [LinkFlair] = []
    @State private var selectedFlairId: String? = nil
    @State private var isFlairRequired: Bool = false
    @State private var isLoadingFlairs = false

    private enum Mode: String, CaseIterable, Identifiable { case write, preview; var id: String { rawValue } }

    enum PostType: String, CaseIterable, Identifiable { case text, link, image; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            Form {
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

                Section(header: Text("Type")) {
                    Picker("Type", selection: $postType) {
                        Text("Text").tag(PostType.text)
                        Text("Link").tag(PostType.link)
                        Text("Image").tag(PostType.image)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Title")) {
                    TextField("Post title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section(header: Text("Flair")) {
                    if !flairs.isEmpty {
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

                if postType == .link {
                    Section(header: Text("Link URL")) {
                        TextField("https://example.com", text: $linkURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                }

                if postType != .link {
                Section(header: Text(postType == .text ? "Body (optional)" : "Caption (optional)")) {
                    VStack(spacing: 0) {
                        // Mode switcher
                        HStack {
                            Picker("Mode", selection: $mode) {
                                Text("Write").tag(Mode.write)
                                Text("Preview").tag(Mode.preview)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.bottom, 8)

                        // Shared markdown toolbar
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

                        // Editor / Preview
                        Group {
                            if mode == .preview {
                                ScrollView {
                                    if postType == .image {
                                        // Show caption if present
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
                            } else {
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
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2), lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if postType == .image {
                            Divider().padding(.vertical, 6)
                            let count = selectedImages.count
                            Text(count == 0 ? "No images attached" : "\(count) image\(count == 1 ? "" : "s") attached")
                                .font(.footnote)
                                .foregroundStyle(count == 0 ? .tertiary : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
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

    private func submit() async {
        guard !isSubmitting else { return }
        let trimmedSub = selectedSubreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSub.isEmpty else {
            await MainActor.run { errorMessage = "Please enter a subreddit (e.g. r/Swift)" }
            return
        }
        isSubmitting = true
        do {
            let clean = trimmedSub.hasPrefix("r/") ? String(trimmedSub.dropFirst(2)) : trimmedSub
            print("[Composer] submit subreddit=\(clean) postType=\(postType) flairId=\(selectedFlairId ?? "<none>")")
            switch postType {
            case .text:
                try await redditAPI.submitTextPost(subreddit: clean, title: title, text: bodyText, flairId: selectedFlairId)
            case .link:
                try await redditAPI.submitLinkPost(subreddit: clean, title: title, url: linkURL, flairId: selectedFlairId)
            case .image:
                try await redditAPI.submitImagePost(subreddit: clean, title: title, caption: bodyText.isEmpty ? nil : bodyText, images: selectedImages, flairId: selectedFlairId)
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
            }
            return
        }
        if !force && !flairs.isEmpty { return }
        isLoadingFlairs = true
        print("[Composer] loadFlairsIfNeeded(force=\(force)) subreddit=\(sub)")
        do {
            let clean = sub.hasPrefix("r/") ? String(sub.dropFirst(2)) : sub
            async let a: [LinkFlair] = try redditAPI.fetchLinkFlairs(subreddit: clean)
            let pt: String = {
                switch postType {
                case .text: return "self"
                case .link: return "link"
                case .image: return "image"
                }
            }()
            async let b: PostRequirements? = try redditAPI.fetchPostRequirements(subreddit: clean, postType: pt)
            var (f, req) = try await (a, b)
            // Filter out mod-only flairs for non-mod users
            f = f.filter { ($0.modOnly ?? false) == false }
            await MainActor.run {
                self.flairs = f
                self.isFlairRequired = (req?.isFlairRequired ?? false)
                print("[Composer] fetched flairs=\(f.count) isFlairRequired=\(self.isFlairRequired)")
                if self.isFlairRequired && self.selectedFlairId == nil { /* keep nil, user must choose */ }
                if !self.isFlairRequired, self.selectedFlairId != nil, !f.contains(where: { $0.id == self.selectedFlairId }) {
                    self.selectedFlairId = nil
                }
            }
        } catch {
            print("[Composer] flair fetch error=\(error.localizedDescription)")
            await MainActor.run {
                self.flairs = []
                self.isFlairRequired = false
            }
        }
        isLoadingFlairs = false
        print("[Composer] loadFlairsIfNeeded finished")
    }
}
