import SwiftUI

// A lightweight, reusable glassy capsule background and icon label
// that works well as a trigger for context menus.
struct GlassCapsuleBackground: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: EdgeInsets = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                // Subtle inner/highlight stroke for depth
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15))
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func glassCapsule(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCapsuleBackground(cornerRadius: cornerRadius))
    }
}

// Menu-friendly icon label with subtle microinteractions (tap haptic + lift)
struct GlassMenuLabel: View {
    let systemImage: String
    let foreground: Color
    let font: Font

    @State private var tappedToggle = false

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .foregroundStyle(foreground)
            .contentShape(Rectangle())
            .glassCapsule()
            .hoverEffect(.lift)
            .sensoryFeedback(.selection, trigger: tappedToggle)
            .simultaneousGesture(
                TapGesture().onEnded { tappedToggle.toggle() }
            )
    }
}

