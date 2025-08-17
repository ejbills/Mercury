//
//  InboxView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/17/25.
//

import SwiftUI

struct InboxView: View {
    let apiService: RedditAPIManager
    @State private var messages: [InboxMessage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter: InboxFilter = .all
    
    enum InboxFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case messages = "Messages"
        case mentions = "Mentions"
        case replies = "Replies"
        
        var icon: String {
            switch self {
            case .all: return "tray.fill"
            case .unread: return "envelope.badge.fill"
            case .messages: return "message.fill"
            case .mentions: return "at.badge.plus"
            case .replies: return "arrowshape.turn.up.left.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterPickerSection
                
                if isLoading && messages.isEmpty {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if messages.isEmpty {
                    emptyStateView
                } else {
                    messagesList
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadMessages()
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    private var filterPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InboxFilter.allCases, id: \.self) { filter in
                    filterButton(for: filter)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(.regularMaterial)
    }
    
    private func filterButton(for filter: InboxFilter) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(filter.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(selectedFilter == filter ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if selectedFilter == filter {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.blue.gradient)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredMessages) { message in
                    messageRow(message)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    
                    if message.id != filteredMessages.last?.id {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func messageRow(_ message: InboxMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.isUnread ? "envelope.fill" : "envelope.open.fill")
                    .font(.caption)
                    .foregroundStyle(message.isUnread ? .blue : .secondary)
                
                Text(message.subject)
                    .font(.headline)
                    .fontWeight(message.isUnread ? .semibold : .medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(message.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("From: u/\(message.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let subreddit = message.subreddit {
                    Text("in r/\(subreddit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text(message.body)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private var filteredMessages: [InboxMessage] {
        switch selectedFilter {
        case .all:
            return messages
        case .unread:
            return messages.filter { $0.isUnread }
        case .messages:
            return messages.filter { $0.type == .privateMessage }
        case .mentions:
            return messages.filter { $0.type == .mention }
        case .replies:
            return messages.filter { $0.type == .commentReply }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading messages...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load inbox")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadMessages()
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text("No Messages")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your inbox is empty. Messages, mentions, and replies will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private func loadMessages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // TODO: Implement actual API call for inbox messages
        // For now, simulate loading with mock data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.messages = mockMessages
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Types

struct InboxMessage: Identifiable {
    let id: String
    let subject: String
    let body: String
    let author: String
    let subreddit: String?
    let isUnread: Bool
    let created: Date
    let type: MessageType
    
    enum MessageType {
        case privateMessage
        case commentReply
        case mention
    }
    
    var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(created)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 2592000 {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return "\(months)mo"
        } else {
            let years = Int(timeInterval / 31536000)
            return "\(years)y"
        }
    }
}

// Mock data for preview/development
private let mockMessages: [InboxMessage] = [
    InboxMessage(
        id: "1",
        subject: "Welcome to Mercury!",
        body: "Thanks for trying out Mercury, the new Reddit client for iOS. We hope you enjoy using the app!",
        author: "mercury_bot",
        subreddit: nil,
        isUnread: true,
        created: Date().addingTimeInterval(-300),
        type: .privateMessage
    ),
    InboxMessage(
        id: "2",
        subject: "Reply to your comment",
        body: "Great point about the new filtering feature! I've been testing it and it works really well.",
        author: "test_user",
        subreddit: "apple",
        isUnread: true,
        created: Date().addingTimeInterval(-3600),
        type: .commentReply
    ),
    InboxMessage(
        id: "3",
        subject: "Username mention",
        body: "Hey u/yourname, thought you might be interested in this new app release!",
        author: "another_user",
        subreddit: "iOSProgramming",
        isUnread: false,
        created: Date().addingTimeInterval(-86400),
        type: .mention
    )
]

#Preview {
    InboxView(apiService: RedditAPIManager())
}