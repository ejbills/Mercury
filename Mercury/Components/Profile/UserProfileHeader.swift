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
    let isFollowing: Bool
    let onFollowToggle: (() -> Void)?
    
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
        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
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
        var all: [(String, String, Color, () -> Void)] = []
        if let onFollowToggle = onFollowToggle {
            all.append((isFollowing ? "person.crop.circle.fill.badge.checkmark" : "person.badge.plus", isFollowing ? "Following" : "Follow", .pink, onFollowToggle))
        }
        all.append(contentsOf: [
            ("message.fill", "Message", .blue, onMessageTap),
            ("square.and.arrow.up", "Share", .green, onShareTap),
            ("safari", "Open", .orange, onOpenWebTap),
            ("doc.on.doc", "Copy", .purple, onCopyTap)
        ])

        let primary = Array(all.prefix(3))
        let overflow = Array(all.dropFirst(3))

        return HStack(spacing: 16) {
            ForEach(0..<primary.count, id: \.self) { i in
                let item = primary[i]
                actionButton(icon: item.0, label: item.1, color: item.2, action: item.3)
            }

            if !overflow.isEmpty {
                Menu {
                    ForEach(0..<overflow.count, id: \.self) { i in
                        let item = overflow[i]
                        Button(action: item.3) {
                            Label(item.1, systemImage: item.0)
                        }
                    }
                } label: {
                    actionButton(icon: "ellipsis.circle", label: "More", color: .gray, action: {})
                }
                .buttonStyle(.plain)
            }

        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .frame(width: 56, height: 56)
                    .background(circleGlass(color: color))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }

    @ViewBuilder
    private func circleGlass(color: Color) -> some View {
        if #available(iOS 26.0, *) {
            Circle().fill(.clear).glassEffect(.regular.tint(Color.black.opacity(0.35))).overlay(Circle().stroke(color.opacity(0.4), lineWidth: 0.8))
        } else {
            Circle().fill(Color.black.opacity(0.35)).overlay(Circle().stroke(color.opacity(0.4), lineWidth: 0.8))
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
                .glassEffect(.regular.tint(.black.opacity(style == .prominent ? 0.35 : 0.22)))
            } else {
                content
                .background(style == .prominent ? Color.black.opacity(0.35) : Color.black.opacity(0.22), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
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
