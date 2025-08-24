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
            VStack(spacing: 12) {
                HStack {
                    Text("To")
                    Spacer()
                    Text("u/\(toUsername)").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    Text("Subject")
                    TextField("Subject", text: $subject)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                ZStack(alignment: .topLeading) {
                    MarkdownTextView(text: $bodyText, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                        .padding(.horizontal)
                    if bodyText.isEmpty {
                        Text("Message in Markdown…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
            }
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