import SwiftUI
import MarkdownUI
import PhotosUI
import UIKit

struct MarkdownComposerView: View {
    let title: String
    let accounts: [String]
    let activeAccount: String?
    let onCancel: () -> Void
    let onSubmit: (_ text: String, _ account: String) async throws -> Void

    @State private var selectedAccount: String

    @State private var text: String = ""
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isFirstResponder: Bool = true
    @State private var isSubmitting = false
    private enum Mode: String, CaseIterable, Identifiable { case write, preview; var id: String { rawValue } }
    @State private var mode: Mode = .write
    @State private var errorMessage: String? = nil

    init(
        title: String,
        accounts: [String],
        activeAccount: String?,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (_ text: String, _ account: String) async throws -> Void
    ) {
        self.title = title
        self.accounts = accounts
        self.activeAccount = activeAccount
        self.onCancel = onCancel
        self.onSubmit = onSubmit

        if let active = activeAccount,
           accounts.contains(where: { $0.caseInsensitiveCompare(active) == .orderedSame }) {
            _selectedAccount = State(initialValue: active)
        } else if let first = accounts.first {
            _selectedAccount = State(initialValue: first)
        } else {
            _selectedAccount = State(initialValue: "")
        }
    }

    @ViewBuilder
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                accountPicker
                modeSwitcher
                toolbar
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .alert("Couldn't post comment", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "Unknown error")
            })
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            HStack { ProgressView().controlSize(.small); Text("Post") }
                        } else {
                            Label("Post", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || resolvedAccount() == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var accountPicker: some View {
        if accounts.isEmpty {
            VStack(spacing: 6) {
                Text("No accounts available")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Add an account in Settings to reply.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Text("Posting as")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Account", selection: $selectedAccount) {
                        ForEach(accounts, id: \.self) { username in
                            Text(username)
                                .lineLimit(1)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .lineLimit(1)
                Divider()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
            }
            .glassCapsule()

            Spacer()
            Text(title).font(.headline)
            Spacer()

            Button(action: submit) {
                if isSubmitting {
                    HStack { ProgressView().controlSize(.small); Text("Posting") }
                        .font(.subheadline)
                } else {
                    Label("Post", systemImage: "paperplane.fill").font(.subheadline)
                }
            }
            .glassCapsule()
            .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.white.opacity(0.18)))
    }

    @ViewBuilder
    private var toolbar: some View {
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

    @ViewBuilder
    private var content: some View {
        Group {
            if mode == .preview {
                ScrollView {
                    MarkdownRenderer(content: text, compactMode: false, showEmbeddedContent: true)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2), lineWidth: 0.5))
                }
            } else {
                ZStack(alignment: .topLeading) {
                    MarkdownTextView(text: $text, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2), lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if text.isEmpty {
                        Text("Write your comment in Markdown…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isFirstResponder = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    @ViewBuilder
    private var modeSwitcher: some View {
        HStack {
            Picker("Mode", selection: $mode) {
                Text("Write").tag(Mode.write)
                Text("Preview").tag(Mode.preview)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.97))
    }

    private func toolChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.25), lineWidth: 0.5))
        }
    }

    // MARK: - Editing helpers
    private func insert(_ snippet: String) {
        let ns = text as NSString
        let loc = max(0, min(selectedRange.location, ns.length))
        let newText = ns.replacingCharacters(in: NSRange(location: loc, length: 0), with: snippet)
        text = newText
        selectedRange = NSRange(location: loc + (snippet as NSString).length, length: 0)
    }

    private func wrap(_ token: String) {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        let selected = ns.substring(with: range)
        let prefix = token
        let suffix = token
        let replacement = prefix + selected + suffix
        text = ns.replacingCharacters(in: range, with: replacement)
        let newLocation = range.location + prefix.count + selected.count
        selectedRange = NSRange(location: newLocation, length: 0)
    }

    private func wrapBlockFence() {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        let selected = ns.substring(with: range)
        let replacement: String
        if selected.isEmpty {
            replacement = "\n```\n\n```\n"
            text = ns.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(location: range.location + 5, length: 0)
        } else {
            replacement = "\n```\n" + selected + "\n```\n"
            text = ns.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(location: range.location + replacement.count, length: 0)
        }
    }

    private func insertAtLineStart(_ token: String) {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
        let newText = ns.replacingCharacters(in: NSRange(location: lineStart, length: 0), with: token)
        text = newText
        let delta = (token as NSString).length
        if range.length == 0 {
            selectedRange = NSRange(location: range.location + delta, length: 0)
        } else {
            selectedRange = NSRange(location: range.location + delta, length: range.length)
        }
    }

    private func prefixLines(_ token: String) {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        let linesRange = ns.lineRange(for: range)
        let substring = ns.substring(with: linesRange)
        let prefixed = substring
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { token + $0 }
            .joined(separator: "\n")
        text = ns.replacingCharacters(in: linesRange, with: prefixed)
        selectedRange = NSRange(location: linesRange.location, length: (prefixed as NSString).length)
    }

    private func prefixLinesNumbered() {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        let linesRange = ns.lineRange(for: range)
        let substring = ns.substring(with: linesRange)
        let lines = substring.split(separator: "\n", omittingEmptySubsequences: false)
        let numbered = lines.enumerated().map { index, line in
            "\(index + 1). " + line
        }.joined(separator: "\n")
        text = ns.replacingCharacters(in: linesRange, with: numbered)
        selectedRange = NSRange(location: linesRange.location, length: (numbered as NSString).length)
    }

    private func insertLink() {
        let ns = text as NSString
        let range = clampedRange(selectedRange, in: ns)
        if range.length > 0 {
            let selected = ns.substring(with: range)
            let replacement = "[\(selected)](https://)"
            text = ns.replacingCharacters(in: range, with: replacement)
            // place cursor inside URL
            selectedRange = NSRange(location: range.location + replacement.count - 1 - "https://)".count, length: 0)
        } else {
            let snippet = "[title](https://)"
            let newText = ns.replacingCharacters(in: NSRange(location: range.location, length: 0), with: snippet)
            text = newText
            // select 'title'
            selectedRange = NSRange(location: range.location + 1, length: 5)
        }
    }

    private func clampedRange(_ range: NSRange, in ns: NSString) -> NSRange {
        let loc = max(0, min(range.location, ns.length))
        let len = max(0, min(range.length, ns.length - loc))
        return NSRange(location: loc, length: len)
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard let account = resolvedAccount() else {
            errorMessage = "Select an account before posting."
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        Task {
            do {
                try await onSubmit(trimmed, account)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
                return
            }
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                isSubmitting = false
                onCancel()
            }
        }
    }

    private func resolvedAccount() -> String? {
        let trimmed = selectedAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return accounts.first
    }
    
}
