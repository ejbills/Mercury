import SwiftUI

struct AlphabeticalSubredditList: View {
    let subreddits: [Subreddit]
    let onSubredditTap: (Subreddit) -> Void
    let onQuickLinkTap: ((QuickLink) -> Void)?
    let multis: [MultiReddit]
    let onMultiTap: ((MultiReddit) -> Void)?
    let favoriteSubreddits: Set<String>
    let onFavoriteToggle: ((Subreddit) -> Void)?
    let subscribedSubreddits: Set<String>
    let onSubscribeToggle: ((Subreddit) -> Void)?
    
    init(
        subreddits: [Subreddit],
        onSubredditTap: @escaping (Subreddit) -> Void,
        onQuickLinkTap: ((QuickLink) -> Void)? = nil,
        multis: [MultiReddit] = [],
        onMultiTap: ((MultiReddit) -> Void)? = nil,
        favoriteSubreddits: Set<String> = Set(),
        onFavoriteToggle: ((Subreddit) -> Void)? = nil,
        subscribedSubreddits: Set<String> = Set(),
        onSubscribeToggle: ((Subreddit) -> Void)? = nil
    ) {
        self.subreddits = subreddits
        self.onSubredditTap = onSubredditTap
        self.onQuickLinkTap = onQuickLinkTap
        self.multis = multis
        self.onMultiTap = onMultiTap
        self.favoriteSubreddits = favoriteSubreddits
        self.onFavoriteToggle = onFavoriteToggle
        self.subscribedSubreddits = subscribedSubreddits
        self.onSubscribeToggle = onSubscribeToggle
    }
    
    private var allSections: [(String, SectionType)] {
        var sections: [(String, SectionType)] = []
        
        // Add quick access section if callback is provided
        if onQuickLinkTap != nil {
            sections.append(("★", .quickAccess(QuickLink.allCases)))
        }
        
        // Add Multireddits if provided
        if onMultiTap != nil && !multis.isEmpty {
            sections.append(("m", .multis(multis)))
        }

        // Add favorites section if there are any favorites
        let favoriteSubs = subreddits.filter { favoriteSubreddits.contains($0.displayName) }
        if !favoriteSubs.isEmpty {
            sections.append(("♥", .favorites(favoriteSubs.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() })))
        }
        
        // Add regular subreddit sections
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
        case multis([MultiReddit])
        case favorites([Subreddit])
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
                            case .multis(let items):
                                ForEach(items, id: \.id) { multi in
                                    MultiRedditRow(multi: multi) {
                                        onMultiTap?(multi)
                                    }
                                }
                            case .favorites(let subreddits):
                                ForEach(subreddits) { subreddit in
                                    SubredditRow(
                                        subreddit: subreddit,
                                        action: { onSubredditTap(subreddit) },
                                        isFavorite: true, // Always true for favorites section
                                        onFavoriteToggle: onFavoriteToggle != nil ? { onFavoriteToggle!(subreddit) } : nil,
                                        isSubscribed: onSubscribeToggle != nil ? subscribedSubreddits.contains(subreddit.displayName) : nil,
                                        onSubscribeToggle: onSubscribeToggle != nil ? { onSubscribeToggle!(subreddit) } : nil
                                    )
                                }
                            case .subreddits(let subreddits):
                                ForEach(subreddits) { subreddit in
                                    SubredditRow(
                                        subreddit: subreddit,
                                        action: { onSubredditTap(subreddit) },
                                        isFavorite: favoriteSubreddits.contains(subreddit.displayName),
                                        onFavoriteToggle: onFavoriteToggle != nil ? { onFavoriteToggle!(subreddit) } : nil,
                                        isSubscribed: onSubscribeToggle != nil ? subscribedSubreddits.contains(subreddit.displayName) : nil,
                                        onSubscribeToggle: onSubscribeToggle != nil ? { onSubscribeToggle!(subreddit) } : nil
                                    )
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
                    } else if title == "m" {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                        Text("Multireddits")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else if title == "♥" {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("Favorites")
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
    @State private var currentIndex: Int? = nil
    
    private let itemHeight: CGFloat = 16
    private let itemSpacing: CGFloat = 2
    private let horizontalPadding: CGFloat = 2
    private let verticalPadding: CGFloat = 4
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: itemSpacing) {
                    ForEach(Array(titles.enumerated()), id: \.0) { idx, title in
                        indexLabel(for: title, isActive: currentIndex == idx)
                            .frame(width: 20, height: itemHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentIndex = idx
                                proxy.animatedScrollTo(title, anchor: UnitPoint.top)
                            }
                    }
                }
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .modifier(GlassContainer())
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Map local Y to index using fixed metrics
                            let localY = value.location.y - verticalPadding
                            let stride = itemHeight + itemSpacing
                            var idx = Int(floor(localY / stride))
                            idx = max(0, min(titles.count - 1, idx))
                            if currentIndex != idx {
                                currentIndex = idx
                                HapticManager.shared.gentleImpact()
                                let title = titles[idx]
                                proxy.animatedScrollTo(title, anchor: UnitPoint.top)
                            }
                        }
                        .onEnded { _ in
                            // No-op; keep size and layout unchanged
                        }
                )
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func indexLabel(for title: String, isActive: Bool) -> some View {
        let color = isActive ? Color.white : Color.blue
        switch title {
        case "★":
            Image(systemName: "star.fill")
                .font(.caption2)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
        case "♥":
            Image(systemName: "heart.fill")
                .font(.caption2)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
        case "m":
            // Multireddit icon instead of the letter "m"
            Image(systemName: "rectangle.3.group.fill")
                .font(.caption2)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
        default:
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

private struct GlassContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Color.blue.opacity(0.22)))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 0.8))
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
