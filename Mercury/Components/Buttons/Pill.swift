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
    
    @State private var isPressed = false
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
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
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
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
