import SwiftUI

struct MarkdownToolsBar: View {
    let onH1: () -> Void
    let onH2: () -> Void
    let onH3: () -> Void
    let onBold: () -> Void
    let onItalic: () -> Void
    let onStrike: () -> Void
    let onCode: () -> Void
    let onBlock: () -> Void
    let onQuote: () -> Void
    let onUL: () -> Void
    let onOL: () -> Void
    let onLink: () -> Void
    let onHR: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("H1", action: onH1)
                chip("H2", action: onH2)
                chip("H3", action: onH3)
                Divider().frame(height: 20)
                chip("B", action: onBold)
                chip("I", action: onItalic)
                chip("S", action: onStrike)
                chip("Code", action: onCode)
                chip("Block", action: onBlock)
                Divider().frame(height: 20)
                chip("Quote", action: onQuote)
                chip("UL", action: onUL)
                chip("OL", action: onOL)
                chip("Link", action: onLink)
                chip("HR", action: onHR)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(
            VStack(spacing: 0) {
                Divider().opacity(0.5)
                Color.clear
            }
        )
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.25), lineWidth: 0.5))
        }
    }
}

