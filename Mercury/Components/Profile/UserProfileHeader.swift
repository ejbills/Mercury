import SwiftUI
import Nuke
import NukeUI
import Glur

struct UserProfileHeader: View {
    let username: String
    let profile: UserProfile?
    let headerAvatarURL: URL?
    let isLoading: Bool
    let onMessageTap: () -> Void
    let onShareTap: () -> Void
    let onOpenWebTap: () -> Void
    let onCopyTap: () -> Void
    
    var body: some View {
        let headerHeight: CGFloat = 400
        let chipsPlaceholderHeight: CGFloat = 32
        
        return ZStack(alignment: .bottom) {
            // Background image with blur
            Group {
                if let url = profile?.profileIconURL ?? headerAvatarURL {
                    LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .opacity((state.image != nil) ? 1 : 0)
                            } else {
                                // Always show neutral background while loading/error
                                neutralBackground
                            }
                    }
                    .priority(.high)
                } else {
                    neutralBackground
                }
            }
            .frame(height: headerHeight)
            .glur(radius: 8.0, offset: 0.4, interpolation: 0.6, direction: .down)
            .mask {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .white],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.08)
                )
                .blur(radius: 3)
            }
            
            // Content overlay
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Text("u/\(username)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                    
                    if let profile {
                        HStack(spacing: 12) {
                            labelChip(
                                system: "arrow.up.circle.fill",
                                text: "\(profile.totalKarma.formatted()) karma",
                                style: .prominent
                            )
                            if let cake = profile.created {
                                labelChip(
                                    system: "gift.fill",
                                    text: cakeDayText(cake),
                                    style: .secondary
                                )
                            }
                        }
                    } else {
                        Color.clear.frame(height: chipsPlaceholderHeight)
                    }
                }
                
                actionsGrid
            }
            .padding(.bottom, 24)
        }
        .frame(height: headerHeight)
    }
    
    private var neutralBackground: some View {
        Rectangle()
            .fill(.quaternary)
    }
    
    private func labelChip(system: String, text: String, style: ChipStyle = .prominent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(ProfileChipGlassModifier(style: style))
    }
    
    private func cakeDayText(_ createdUTC: Double) -> String {
        let date = Date(timeIntervalSince1970: createdUTC)
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
    
    private var accentColor: Color {
        let colors: [Color] = [.orange, .pink, .purple, .blue, .teal, .mint, .indigo]
        return colors[abs(username.hashValue) % colors.count]
    }
    
    private var actionsGrid: some View {
        let items: [(String, String, Color, () -> Void)] = [
            ("message.fill", "Message", .blue, onMessageTap),
            ("square.and.arrow.up", "Share", .green, onShareTap),
            ("safari", "Open", .orange, onOpenWebTap),
            ("doc.on.doc", "Copy", .purple, onCopyTap)
        ]
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
            spacing: 16
        ) {
            ForEach(0..<items.count, id: \.self) { i in
                let item = items[i]
                VStack(spacing: 8) {
                    Button(action: item.3) {
                        Image(systemName: item.0)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .modifier(ProfileActionGlassModifier())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Text(item.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

enum ChipStyle {
    case prominent
    case secondary
}

private struct ProfileChipGlassModifier: ViewModifier {
    let style: ChipStyle
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(style == .prominent ? 0.22 : 0.14)))
        } else {
            content
                .background(style == .prominent ? Material.ultraThinMaterial : Material.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
        }
    }
}

private struct ProfileActionGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(0.18)))
                .hoverEffect(.lift)
        } else {
            content
                .background(Circle().fill(.white.opacity(0.15)))
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}
