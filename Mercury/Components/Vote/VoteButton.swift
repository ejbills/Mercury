import SwiftUI
import UIKit

enum VoteDirectionKind {
    case up
    case down
}

enum VoteButtonSize {
    case small
    case medium
    case large
}

struct VoteButton: View {
    let direction: VoteDirectionKind
    let isActive: Bool
    let size: VoteButtonSize
    let colorScheme: ColorScheme
    let disabled: Bool
    let action: () -> Void

    init(direction: VoteDirectionKind,
         isActive: Bool,
         size: VoteButtonSize,
         colorScheme: ColorScheme = .light,
         disabled: Bool = false,
         action: @escaping () -> Void) {
        self.direction = direction
        self.isActive = isActive
        self.size = size
        self.colorScheme = colorScheme
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemImage)
                .font(font)
                .fontWeight(.semibold)
                .foregroundStyle(isActive ? Color.white : Color.secondary)
                .frame(width: buttonSize, height: buttonSize)
                .background(isActive ? activeFill : Color.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isActive ? activeFill : strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        action()
    }

    private var systemImage: String { direction == .up ? "arrow.up" : "arrow.down" }

    private var activeFill: Color { direction == .up ? .orange : .blue }

    private var strokeColor: Color { colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3) }

    private var buttonSize: CGFloat {
        switch size {
        case .small: return 24
        case .medium: return 32
        case .large: return 44
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }

    private var font: Font {
        switch size {
        case .small: return .footnote
        case .medium: return .callout
        case .large: return .title2
        }
    }
}
