import SwiftUI
import UIKit

/// Attaches a long-press recognizer to the first UITabBar found and calls a callback when
/// the given tab index is long-pressed.
struct TabBarLongPressObserver: UIViewRepresentable {
    let targetIndex: Int
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        DispatchQueue.main.async { attachRecognizerIfNeeded(context: context) }
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { attachRecognizerIfNeeded(context: context) }
    }

    private func attachRecognizerIfNeeded(context: Context) {
        guard let tabBar = findTabBar(), let targetButton = tabBarButton(in: tabBar, at: targetIndex) else { return }
        let key = "MercuryProfileLongPress"
        // Avoid duplicate recognizers on the target tab button only
        if let recognizers = targetButton.gestureRecognizers, recognizers.contains(where: { ($0 as? UILongPressGestureRecognizer)?.name == key }) {
            return
        }
        let lp = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        lp.minimumPressDuration = 0.7
        lp.cancelsTouchesInView = false
        lp.delaysTouchesBegan = false
        lp.requiresExclusiveTouchType = false
        lp.name = key
        lp.delegate = context.coordinator
        targetButton.addGestureRecognizer(lp)
    }

    func makeCoordinator() -> Coordinator { Coordinator(targetIndex: targetIndex, onLongPress: onLongPress) }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let targetIndex: Int
        let onLongPress: () -> Void
        init(targetIndex: Int, onLongPress: @escaping () -> Void) {
            self.targetIndex = targetIndex
            self.onLongPress = onLongPress
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            onLongPress()
        }

        // Allow simultaneous recognition so taps still work
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        // Never require failure of system gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }

    private func findTabBar() -> UITabBar? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let tabBar = findTabBar(in: window) { return tabBar }
            }
        }
        return nil
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        for sub in view.subviews {
            if let bar = findTabBar(in: sub) { return bar }
        }
        return nil
    }

    // Attempt to find the UIControl representing the tab at a given index
    private func tabBarButton(in tabBar: UITabBar, at index: Int) -> UIControl? {
        // UITabBarButton is a private class, but it's a UIControl. Order subviews by x-position.
        let buttons = tabBar.subviews.compactMap { $0 as? UIControl }.sorted { $0.frame.minX < $1.frame.minX }
        guard index >= 0 && index < buttons.count else { return nil }
        return buttons[index]
    }
}
