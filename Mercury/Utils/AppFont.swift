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
            return 18 * titleScale        // slightly smaller default title
        case .body:
            return 16 * bodyScale         // standard body size
        case .meta:
            return 14 * captionScale      // subheadline/meta smaller by default
        case .caption:
            return 12 * captionScale      // caption
        case .small:
            return 11 * captionScale      // tiny caption
        }
    }
}

extension View {
    func appFont(_ role: AppTextRole, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(role: role, weight: weight))
    }
}
