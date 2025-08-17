//
//  NotchHeaderPill.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//


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
        .background(.gray.opacity(0.15), in: Capsule())
        .background(.thinMaterial.opacity(0.75), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.separator.opacity(0.2), lineWidth: 0.5)
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

enum PillSize {
    case small
    case regular
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 6
        case .regular: return 12
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .regular: return 6
        }
    }
    
    var contentSpacing: CGFloat {
        switch self {
        case .small: return 3
        case .regular: return 6
        }
    }
}
