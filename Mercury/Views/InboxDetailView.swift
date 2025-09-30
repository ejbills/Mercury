import SwiftUI

struct InboxDetailView: View {
    let item: InboxItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.redditAPI) private var redditAPI
    @State private var showContext = false
    @State private var replyText: String = ""
    @State private var selectedRange: NSRange = .init(location: 0, length: 0)
    @State private var isFirstResponder: Bool = true
    @State private var isSending = false
    @State private var sendError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Card(style: .default) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                UserAvatar(username: item.author, size: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.subject)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    HStack(spacing: 6) {
                                        Text("u/\(item.author)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if let sub = item.subreddit {
                                            Text("• r/\(sub)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("• \(item.timeAgo)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Text(item.body)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if item.type == .privateMessage {
                        Card(style: .default) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reply")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                ZStack(alignment: .topLeading) {
                                    MarkdownTextView(text: $replyText, selectedRange: $selectedRange, isFirstResponder: $isFirstResponder)
                                        .frame(minHeight: 140, alignment: .topLeading)
                                    if replyText.isEmpty {
                                        Text("Write your reply in Markdown…")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.gray.opacity(0.2), lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(isSending)
                                HStack {
                                    if let sendError = sendError {
                                        Text(sendError)
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    }
                                    Spacer()
                                    PrimaryButton(isSending ? "Sending…" : "Send", icon: "paperplane.fill") {
                                        Task { await sendReply() }
                                    }
                                    .disabled(isSending || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    }

                    if let url = item.contextURL {
                        Card(style: .compact) {
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.blue)
                                Text("View in context")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showContext = true
                            }
                        }
                        .sheet(isPresented: $showContext) {
                            SafariView(url: url)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch item.type {
        case .privateMessage: return "Message"
        case .commentReply: return "Comment Reply"
        case .mention: return "Mention"
        }
    }
    
    @MainActor
    private func sendReply() async {
        guard let fullname = item.fullName else { return }
        isSending = true
        sendError = nil
        do {
            try await redditAPI.replyToMessage(fullname: fullname, text: replyText)
            isSending = false
            dismiss()
        } catch {
            sendError = error.localizedDescription
            isSending = false
        }
    }
}
