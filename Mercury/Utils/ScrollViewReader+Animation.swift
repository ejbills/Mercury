import SwiftUI

extension ScrollViewProxy {
    /// Animates scroll to the specified anchor with a snappy animation
    func animatedScrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint = .center) {
        withAnimation(.snappy(duration: 0.125)) {
            scrollTo(id, anchor: anchor)
        }
    }
}