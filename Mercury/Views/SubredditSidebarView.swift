import SwiftUI

struct SubredditSidebarView: View {
    let subreddit: String
    let apiService: RedditAPIManager

    @State private var about: Subreddit?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCompose = false

    private var titleText: String {
        subreddit.hasPrefix("r/") ? subreddit : "r/\(subreddit)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading sidebar…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Failed to load sidebar").font(.headline)
                        Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let about = about {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                SubredditIcon(iconURL: about.iconURL, displayName: about.displayName, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(about.displayNamePrefixed).font(.headline)
                                    Text("\(about.memberCountText) members").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.bottom, 8)

                            if !about.publicDescription.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("About").font(.subheadline).fontWeight(.semibold)
                                    MarkdownRenderer(content: about.publicDescription, compactMode: false, showEmbeddedContent: true)
                                }
                            }

                            if !about.description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sidebar").font(.subheadline).fontWeight(.semibold)
                                    MarkdownRenderer(content: about.description, compactMode: false, showEmbeddedContent: true)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.visible)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCompose = true
                    } label: {
                        Label("Message Mods", systemImage: "envelope.fill")
                    }
                    .disabled(about == nil)
                }
            }
        }
        .onAppear { Task { await load() } }
        .sheet(isPresented: $showCompose) {
            if let about {
                let name = about.displayName
                ComposeMessageSheet(toUsername: "r/\(name)", isPresented: $showCompose)
                    .environment(\.redditAPI, apiService)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let data = try await apiService.fetchSubredditAbout(subreddit: subreddit)
            await MainActor.run { about = data; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
}

#Preview {
    SubredditSidebarView(subreddit: "swift", apiService: RedditAPIManager())
}
