import SwiftUI
import Defaults

enum AppTextRole {
    case title
    case body
    case meta
    case caption
    case small
}

struct AppFontModifier: ViewModifier {
    let role: AppTextRole
    let weight: Font.Weight

    // Scales are Defaults-backed to propagate updates live
    @Default(.titleTextScale) private var titleScale
    @Default(.bodyTextScale) private var bodyScale
    @Default(.captionTextScale) private var captionScale

    func body(content: Content) -> some View {
        content.font(.system(size: pointSize(for: role), weight: weight))
    }

    private func pointSize(for role: AppTextRole) -> CGFloat {
        switch role {
        case .title:
            return 20 * titleScale        // baseline ~ title3
        case .body:
            return 17 * bodyScale         // baseline ~ body
        case .meta:
            return 15 * captionScale      // baseline ~ subheadline
        case .caption:
            return 12 * captionScale      // baseline ~ caption1
        case .small:
            return 11 * captionScale      // baseline ~ caption2
        }
    }
}

extension View {
    func appFont(_ role: AppTextRole, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(role: role, weight: weight))
    }
}

