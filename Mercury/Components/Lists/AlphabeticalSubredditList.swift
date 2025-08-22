import SwiftUI

struct AlphabeticalSubredditList: View {
    let subreddits: [Subreddit]
    let onSubredditTap: (Subreddit) -> Void
    let onQuickLinkTap: ((QuickLink) -> Void)?
    
    init(subreddits: [Subreddit], onSubredditTap: @escaping (Subreddit) -> Void, onQuickLinkTap: ((QuickLink) -> Void)? = nil) {
        self.subreddits = subreddits
        self.onSubredditTap = onSubredditTap
        self.onQuickLinkTap = onQuickLinkTap
    }
    
    private var allSections: [(String, SectionType)] {
        var sections: [(String, SectionType)] = []
        
        // Add quick access section if callback is provided
        if onQuickLinkTap != nil {
            sections.append(("★", .quickAccess(QuickLink.allCases)))
        }
        
        // Add subreddit sections
        let subredditSections = groupedSubreddits.map { ($0.0, SectionType.subreddits($0.1)) }
        sections.append(contentsOf: subredditSections)
        
        return sections
    }
    
    private var groupedSubreddits: [(String, [Subreddit])] {
        let sorted = subreddits.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        
        let grouped = Dictionary(grouping: sorted) { subreddit in
            let firstChar = subreddit.displayName.prefix(1).uppercased()
            return firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil ? firstChar : "#"
        }
        
        return grouped.sorted { first, second in
            if first.key == "#" && second.key != "#" {
                return false
            } else if first.key != "#" && second.key == "#" {
                return true
            } else {
                return first.key < second.key
            }
        }
    }
    
    private var sectionIndexTitles: [String] {
        allSections.map { $0.0 }
    }
    
    private enum SectionType {
        case quickAccess([QuickLink])
        case subreddits([Subreddit])
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                List {
                    ForEach(allSections, id: \.0) { section in
                        Section(header: sectionHeader(section.0)) {
                            switch section.1 {
                            case .quickAccess(let quickLinks):
                                QuickAccessGrid(quickLinks: quickLinks, onQuickLinkTap: onQuickLinkTap)
                                    .listRowSeparator(.hidden)
                            case .subreddits(let subreddits):
                                ForEach(subreddits) { subreddit in
                                    SubredditRow(subreddit: subreddit) {
                                        onSubredditTap(subreddit)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                // Section index overlay
                if !allSections.isEmpty {
                    SectionIndexTitles(
                        proxy: proxy,
                        titles: sectionIndexTitles
                    )
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Pill(size: .regular) {
                HStack(spacing: 6) {
                    if title == "★" {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("Quick Access")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .id(title)
    }
}


struct SectionIndexTitles: View {
    let proxy: ScrollViewProxy
    let titles: [String]
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    ForEach(titles, id: \.self) { title in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(title, anchor: UnitPoint.top)
                            }
                        }) {
                            Text(title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(radius: 2)
                )
            }
            Spacer()
        }
    }
}

#Preview {
    let sampleJSON1 = """
    {
        "id": "2qh33",
        "display_name": "Apple",
        "display_name_prefixed": "r/Apple",
        "title": "Apple",
        "description": "Apple products and news",
        "subscribers": 2000000,
        "over18": false,
        "public_description": "Apple discussion"
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
        "display_name": "funny",
        "display_name_prefixed": "r/funny",
        "title": "funny",
        "description": "Funny content",
        "subscribers": 50000000,
        "over18": false,
        "public_description": "A place for funny content"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    let sampleSubreddits = [
        try! decoder.decode(Subreddit.self, from: sampleJSON1),
        try! decoder.decode(Subreddit.self, from: sampleJSON2),
        try! decoder.decode(Subreddit.self, from: sampleJSON3)
    ]
    
    return AlphabeticalSubredditList(subreddits: sampleSubreddits) { _ in }
        .frame(height: 600)
}

struct QuickAccessGrid: View {
    let quickLinks: [QuickLink]
    let onQuickLinkTap: ((QuickLink) -> Void)?
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(quickLinks, id: \.self) { link in
                quickLinkCard(for: link)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    
    private func quickLinkCard(for link: QuickLink) -> some View {
        Button(action: {
            onQuickLinkTap?(link)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconGradient(for: link))
                        .frame(width: 50, height: 50)
                        .shadow(color: shadowColor(for: link), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: link.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text(link.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func iconGradient(for link: QuickLink) -> LinearGradient {
        switch link {
        case .home:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .popular:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .all:
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .saved:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func shadowColor(for link: QuickLink) -> Color {
        switch link {
        case .home:
            return .blue.opacity(0.3)
        case .popular:
            return .orange.opacity(0.3)
        case .all:
            return .purple.opacity(0.3)
        case .saved:
            return .green.opacity(0.3)
        }
    }
}

