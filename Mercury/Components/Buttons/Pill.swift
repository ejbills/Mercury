import SwiftUI

struct Pill<Content: View>: View {
    let content: () -> Content
    let action: (() -> Void)?
    let size: PillSize
    
    @State private var isPressed = false
    
    init(action: (() -> Void)? = nil, size: PillSize = .regular, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.size = size
        self.content = content
    }

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    pillContent
                }
                .buttonStyle(PillButtonStyle())
            } else {
                pillContent
            }
        }
    }
    
    private var pillContent: some View {
        HStack(spacing: size.contentSpacing) {
            content()
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.gray.opacity(0.3), lineWidth: 0.4)
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}

// (Reverted) Keep lightweight material-based styling for performance.

enum PillSize {
    case small
    case regular
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .regular: return 6
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 3
        case .regular: return 4
        }
    }
    
    var contentSpacing: CGFloat {
        switch self {
        case .small: return 2
        case .regular: return 4
        }
    }
}
