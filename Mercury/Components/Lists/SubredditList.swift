import SwiftUI

struct SubredditList: View {
    let subreddits: [Subreddit]
    let showLimit: Int?
    let useCardStyle: Bool
    let onSubredditTap: (Subreddit) -> Void
    let onShowAllTap: (() -> Void)?
    
    init(
        subreddits: [Subreddit],
        showLimit: Int? = nil,
        useCardStyle: Bool = true,
        onSubredditTap: @escaping (Subreddit) -> Void,
        onShowAllTap: (() -> Void)? = nil
    ) {
        self.subreddits = subreddits
        self.showLimit = showLimit
        self.useCardStyle = useCardStyle
        self.onSubredditTap = onSubredditTap
        self.onShowAllTap = onShowAllTap
    }
    
    private var displayedSubreddits: [Subreddit] {
        if let showLimit = showLimit {
            return Array(subreddits.prefix(showLimit))
        }
        return subreddits
    }
    
    private var hasMoreItems: Bool {
        guard let showLimit = showLimit else { return false }
        return subreddits.count > showLimit
    }
    
    var body: some View {
        Group {
            if useCardStyle {
                MaterialCard {
                    subredditListContent
                }
            } else {
                subredditListContent
            }
        }
    }
    
    private var subredditListContent: some View {
        VStack(spacing: 0) {
            ForEach(displayedSubreddits) { subreddit in
                SubredditRow(subreddit: subreddit) {
                    onSubredditTap(subreddit)
                }
                
                if subreddit.id != displayedSubreddits.last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
            
            if hasMoreItems, let onShowAllTap = onShowAllTap {
                Button("Show All (\(subreddits.count))") {
                    onShowAllTap()
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 16)
            }
        }
    }
}

#Preview {
    let sampleJSON1 = """
    {
        "id": "2qh33",
        "display_name": "funny",
        "display_name_prefixed": "r/funny",
        "title": "funny",
        "description": "Welcome to r/Funny",
        "subscribers": 52000000,
        "over18": false,
        "public_description": "A place for funny content"
    }
    """.data(using: .utf8)!
    
    let sampleJSON2 = """
    {
        "id": "2qh34",
        "display_name": "SwiftUI",
        "display_name_prefixed": "r/SwiftUI",
        "title": "SwiftUI",
        "description": "SwiftUI discussions",
        "subscribers": 150000,
        "over18": false,
        "public_description": "SwiftUI development"
    }
    """.data(using: .utf8)!
    
    let sampleJSON3 = """
    {
        "id": "2qh35",
        "display_name": "iOS",
        "display_name_prefixed": "r/iOS",
        "title": "iOS",
        "description": "iOS discussions",
        "subscribers": 500000,
        "over18": false,
        "public_description": "iOS development and news"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    let sampleSubreddits = [
        try! decoder.decode(Subreddit.self, from: sampleJSON1),
        try! decoder.decode(Subreddit.self, from: sampleJSON2),
        try! decoder.decode(Subreddit.self, from: sampleJSON3)
    ]
    
    return VStack(spacing: 20) {
        // Card style with limit
        SubredditList(
            subreddits: sampleSubreddits,
            showLimit: 2,
            useCardStyle: true,
            onSubredditTap: { _ in },
            onShowAllTap: { }
        )
        
        // Plain style without limit
        SubredditList(
            subreddits: Array(sampleSubreddits.prefix(2)),
            useCardStyle: false,
            onSubredditTap: { _ in }
        )
    }
    .padding()
}