import SwiftUI

struct FeedBackgroundModifier: ViewModifier {
    let style: FeedBackgroundStyle
    let customColor: Color?

    func body(content: Content) -> some View {
        content
            .background(style.resolveColor(custom: customColor).ignoresSafeArea())
    }
}

extension View {
    func feedBackground(style: FeedBackgroundStyle, customColor: Color?) -> some View {
        modifier(FeedBackgroundModifier(style: style, customColor: customColor))
    }
}
