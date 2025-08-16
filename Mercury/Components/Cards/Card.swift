//
//  Card.swift
//  Mercury
//
//  Created by AI Assistant on 1/20/25.
//

import SwiftUI

/// Base card component providing uniform styling across the entire app
struct Card<Content: View>: View {
    let content: () -> Content
    let style: CardStyle
    let interactionMode: CardInteractionMode
    
    @State private var isPressed = false
    
    init(
        style: CardStyle = .default,
        interactionMode: CardInteractionMode = .none,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.style = style
        self.interactionMode = interactionMode
    }
    
    var body: some View {
        content()
            .padding(style.padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(
                        style.accentColor != nil ? 
                        LinearGradient(
                            stops: [
                                .init(color: style.accentColor!, location: 0.0),
                                .init(color: style.accentColor!.opacity(0.3), location: 0.08),
                                .init(color: style.borderColor, location: 0.08),
                                .init(color: style.borderColor, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) : LinearGradient(colors: [style.borderColor], startPoint: .leading, endPoint: .trailing),
                        lineWidth: style.borderWidth
                    )
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                if case .tappable(let action) = interactionMode {
                    action()
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
                if case .tappable = interactionMode {
                    isPressed = pressing
                }
            } perform: {}
    }
}

/// Card styling options
struct CardStyle {
    let padding: EdgeInsets
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let accentColor: Color?
    let accentWidth: CGFloat
    let accentPosition: Alignment
    
    static let `default` = CardStyle(
        padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: 16,
        backgroundColor: Color.clear,
        borderColor: .gray.opacity(0.3),
        borderWidth: 0.5,
        accentColor: nil,
        accentWidth: 0,
        accentPosition: .leading
    )
    
    static let compact = CardStyle(
        padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        cornerRadius: 12,
        backgroundColor: Color.clear,
        borderColor: .gray.opacity(0.3),
        borderWidth: 0.5,
        accentColor: nil,
        accentWidth: 0,
        accentPosition: .leading
    )
    
    static let minimal = CardStyle(
        padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
        cornerRadius: 8,
        backgroundColor: Color.clear,
        borderColor: .gray.opacity(0.2),
        borderWidth: 0.5,
        accentColor: nil,
        accentWidth: 0,
        accentPosition: .leading
    )
    
    static func withAccent(_ color: Color, width: CGFloat = 3, position: Alignment = .leading) -> CardStyle {
        return CardStyle(
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            cornerRadius: 16,
            backgroundColor: Color.clear,
            borderColor: .gray.opacity(0.3),
            borderWidth: 0.5,
            accentColor: color,
            accentWidth: width,
            accentPosition: position
        )
    }
    
    static func comment(depth: Int = 0, accentColor: Color? = nil) -> CardStyle {
        return CardStyle(
            padding: EdgeInsets(top: depth == 0 ? 16 : 12, leading: 16, bottom: depth == 0 ? 16 : 12, trailing: 16),
            cornerRadius: depth == 0 ? 16 : 12,
            backgroundColor: Color.clear,
            borderColor: .gray.opacity(0.3),
            borderWidth: 0.5,
            accentColor: depth > 0 ? accentColor : nil,
            accentWidth: 4,
            accentPosition: .leading
        )
    }
}

/// Card interaction modes
enum CardInteractionMode {
    case none
    case tappable(() -> Void)
}

// MARK: - Convenience Modifiers

extension Card {
    func onTap(_ action: @escaping () -> Void) -> Card<Content> {
        Card(style: style, interactionMode: .tappable(action), content: content)
    }
}

