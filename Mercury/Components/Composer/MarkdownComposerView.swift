import SwiftUI
import MarkdownUI
import UIKit

struct MarkdownComposerView: View {
    let title: String
    let onCancel: () -> Void
    let onSubmit: (_ text: String) async throws -> Void

    @State private var text: String = ""
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isFirstResponder: Bool = true
    @State private var isSubmitting = false
    @State private var showPreview = false
    @State private var errorMessage: String? = nil

    @ViewBuilder
    var body: some View {
        VStack(spacing: 0) {
            header
            toolbar
            content
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("Couldn't post comment", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Button("Cancel") { onCancel() }
            Spacer()
            Text(title).font(.headline)
            Spacer()
            Button(action: submit) {
                if isSubmitting { ProgressView().controlSize(.small) } else { Text("Post") }
            }
            .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("H1") { insertAtLineStart("# ") }
                pill("H2") { insertAtLineStart("## ") }
                pill("H3") { insertAtLineStart("### ") }
                Divider().frame(height: 20)
                pill("B") { wrap("**") }
                pill("I") { wrap("*") }
                pill("S") { wrap("~~") }
                pill("Code") { wrap("`") }
                pill("Block") { wrapBlockFence() }
                Divider().frame(height: 20)
                pill("Quote") { prefixLines("> ") }
                pill("UL") { prefixLines("- ") }
                pill("OL") { prefixLinesNumbered() }
                pill("Link") { insertLink() }
                pill("HR") { insert("\n\n---\n\n") }
                Divider().frame(height: 20)
                pill("Table") { insert("\n| Col A | Col B |\n| --- | --- |\n|  |  |\n") }
            }
            .padding(.vertical, 4)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if showPreview {
                ScrollView {
                        Markdown(text)
                            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    MarkdownTextView(text: $text, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)

                    if text.isEmpty {
                        Text("Write your comment in Markdown…")
                            .foregroundStyle(.secondary)
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
    private var footer: some View {
        HStack {
            Pill(action: {
                showPreview.toggle()
            }, content: {
                Label(showPreview ? "Write" : "Preview", systemImage: showPreview ? "pencil" : "eye")
            })

            Spacer()
            Text("\(text.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Pill(size: .regular) {
                Text(title).font(.caption)
            }
        }
        .buttonStyle(.plain)
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
        isSubmitting = true
        Task {
            do {
                try await onSubmit(text)
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
}
