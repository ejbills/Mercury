import SwiftUI

struct ComposeMessageSheet: View {
    let toUsername: String
    @Binding var isPresented: Bool
    @Environment(\.redditAPI) private var redditAPI
    @State private var subject: String = ""
    @State private var bodyText: String = ""
    @State private var selectedRange: NSRange = .init(location: 0, length: 0)
    @State private var isFirstResponder: Bool = true
    @State private var isSending = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("To")
                        Spacer()
                        let display = toUsername.hasPrefix("r/") ? toUsername : "u/\(toUsername)"
                        Text(display).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                Section(header: Text("Subject")) {
                    TextField("Subject", text: $subject)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                }
                Section(header: Text("Message")) {
                    ZStack(alignment: .topLeading) {
                        MarkdownTextView(text: $bodyText, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                            .frame(minHeight: 220, alignment: .topLeading)
                        if bodyText.isEmpty {
                            Text("Write your message in Markdown…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending { ProgressView() } else { Text("Send") }
                    }
                    .disabled(isSending || subject.trimmingCharacters(in: .whitespaces).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn't send message", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "Unknown error")
            }
        }
    }
    
    private func send() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await redditAPI.composePrivateMessage(to: toUsername, subject: subject, text: bodyText)
            await MainActor.run { isPresented = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
