import SwiftUI
import Defaults

struct FilterSettingsView: View {
    @Default(.keywordFilterEnabled) private var keywordFilterEnabled
    @Default(.userBlockingEnabled) private var userBlockingEnabled
    @Default(.subredditBlockingEnabled) private var subredditBlockingEnabled
    @Default(.blockedKeywords) private var blockedKeywords
    @Default(.blockedUsers) private var blockedUsers
    @Default(.blockedSubreddits) private var blockedSubreddits
    @Default(.hiddenPostIds) private var hiddenPostIds
    
    @State private var newKeyword = ""
    @State private var newUser = ""
    @State private var newSubreddit = ""
    @State private var showingAddKeyword = false
    @State private var showingAddUser = false
    @State private var showingAddSubreddit = false
    
    // Stable, sorted arrays to avoid list reshuffling during state changes/typing
    private var sortedBlockedKeywords: [String] {
        Array(blockedKeywords).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private var sortedBlockedUsers: [String] {
        Array(blockedUsers).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private var sortedBlockedSubreddits: [String] {
        Array(blockedSubreddits).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Filter Settings") {
                    Toggle("Keyword Filtering", isOn: $keywordFilterEnabled)
                    Toggle("User Blocking", isOn: $userBlockingEnabled)
                    Toggle("Subreddit Blocking", isOn: $subredditBlockingEnabled)
                }
                
                Section {
                    ForEach(sortedBlockedKeywords, id: \.self) { keyword in
                        HStack {
                            Text(keyword)
                            Spacer()
                            Button("Remove") {
                                FilterService.shared.removeBlockedKeyword(keyword)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .onDelete(perform: deleteKeywords)
                    
                    Button("Add Keyword") {
                        showingAddKeyword = true
                    }
                    .foregroundColor(.blue)
                } header: {
                    HStack {
                        Text("Blocked Keywords")
                        Spacer()
                        Text("(\(blockedKeywords.count))")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    ForEach(sortedBlockedUsers, id: \.self) { user in
                        HStack {
                            Text("u/\(user)")
                            Spacer()
                            Button("Remove") {
                                FilterService.shared.removeBlockedUser(user)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .onDelete(perform: deleteUsers)
                    
                    Button("Add User") {
                        showingAddUser = true
                    }
                    .foregroundColor(.blue)
                } header: {
                    HStack {
                        Text("Blocked Users")
                        Spacer()
                        Text("(\(blockedUsers.count))")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    ForEach(sortedBlockedSubreddits, id: \.self) { subreddit in
                        HStack {
                            Text("r/\(subreddit)")
                            Spacer()
                            Button("Remove") {
                                FilterService.shared.removeBlockedSubreddit(subreddit)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .onDelete(perform: deleteSubreddits)
                    
                    Button("Add Subreddit") {
                        showingAddSubreddit = true
                    }
                    .foregroundColor(.blue)
                } header: {
                    HStack {
                        Text("Blocked Subreddits")
                        Spacer()
                        Text("(\(blockedSubreddits.count))")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    if hiddenPostIds.isEmpty {
                        Text("No hidden posts")
                            .foregroundColor(.secondary)
                    } else {
                        Button("Clear All Hidden Posts") {
                            hiddenPostIds.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    HStack {
                        Text("Hidden Posts")
                        Spacer()
                        Text("(\(hiddenPostIds.count))")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Posts hidden using the 'Hide' and 'Hide Posts Above' swipe actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Content Filters")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Add Keyword", isPresented: $showingAddKeyword) {
            TextField("Keyword", text: $newKeyword)
            Button("Cancel", role: .cancel) { 
                newKeyword = ""
            }
            Button("Add") {
                if !newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    FilterService.shared.addBlockedKeyword(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines))
                    newKeyword = ""
                }
            }
        } message: {
            Text("Enter a keyword to block from posts and comments")
        }
        .alert("Add User", isPresented: $showingAddUser) {
            TextField("Username", text: $newUser)
            Button("Cancel", role: .cancel) { 
                newUser = ""
            }
            Button("Add") {
                if !newUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let cleanUser = newUser.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "u/", with: "")
                    FilterService.shared.addBlockedUser(cleanUser)
                    newUser = ""
                }
            }
        } message: {
            Text("Enter a username to block (without u/)")
        }
        .alert("Add Subreddit", isPresented: $showingAddSubreddit) {
            TextField("Subreddit", text: $newSubreddit)
            Button("Cancel", role: .cancel) { 
                newSubreddit = ""
            }
            Button("Add") {
                if !newSubreddit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let cleanSubreddit = newSubreddit.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "r/", with: "")
                    FilterService.shared.addBlockedSubreddit(cleanSubreddit)
                    newSubreddit = ""
                }
            }
        } message: {
            Text("Enter a subreddit to block (without r/)")
        }
    }
    
    private func deleteKeywords(offsets: IndexSet) {
        let keywordsArray = sortedBlockedKeywords
        for index in offsets {
            FilterService.shared.removeBlockedKeyword(keywordsArray[index])
        }
    }
    
    private func deleteUsers(offsets: IndexSet) {
        let usersArray = sortedBlockedUsers
        for index in offsets {
            FilterService.shared.removeBlockedUser(usersArray[index])
        }
    }
    
    private func deleteSubreddits(offsets: IndexSet) {
        let subredditsArray = sortedBlockedSubreddits
        for index in offsets {
            FilterService.shared.removeBlockedSubreddit(subredditsArray[index])
        }
    }
}

#Preview {
    FilterSettingsView()
}
