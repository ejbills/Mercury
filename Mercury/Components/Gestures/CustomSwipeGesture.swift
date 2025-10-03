import SwiftUI
import Defaults

private enum SwipeConstants {
    // Right-side only thresholds, tuned for easy activation
    // Each level is progressively farther to avoid accidental triggers
    static let level1: CGFloat = 70
    static let level2: CGFloat = 120
    static let level3: CGFloat = 170
    static let level4: CGFloat = 230
}

struct SwipeGestureModifier: ViewModifier {
    @GestureState private var dragState: CGFloat = .zero
    @State private var dragPosition: CGFloat = .zero
    @State private var prevDragPosition: CGFloat = .zero
    @State private var dragBackground: Color?
    @State private var trailingSwipeSymbol: String?

    // Right-side only actions (up to four)
    private let trailingAction1: SwipeAction?
    private let trailingAction2: SwipeAction?
    private let trailingAction3: SwipeAction?
    private let trailingAction4: SwipeAction?
    
    @Default(.swipeActionsEnabled) private var swipeActionsEnabled
    
    init(trailingAction1: SwipeAction?,
         trailingAction2: SwipeAction?,
         trailingAction3: SwipeAction?,
         trailingAction4: SwipeAction?
    ) {
        self.trailingAction1 = trailingAction1
        self.trailingAction2 = trailingAction2
        self.trailingAction3 = trailingAction3
        self.trailingAction4 = trailingAction4

        _trailingSwipeSymbol = State(initialValue: trailingAction1?.symbol.emptyName)
    }
    
    func body(content: Content) -> some View {
        if swipeActionsEnabled {
            content
                    .background {
                        GeometryReader { proxy in
                            Rectangle()
                                .foregroundColor(.clear)
                        }
                    }
                    .offset(x: dragPosition)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 40, coordinateSpace: .global)
                            .updating($dragState) { value, state, _ in
                                // Only respond to right-side (trailing) swipes; ignore left/back gesture area
                                state = value.translation.width
                            }
                    )
                    .onChange(of: dragState) { _, newDragState in
                        if newDragState == .zero {
                            draggingDidEnd()
                        } else {
                            guard shouldRespondToDragPosition(newDragState) else { return }
                            
                            dragPosition = newDragState
                            updateSwipeState(for: dragPosition)
                        }
                    }
                    .background {
                        GeometryReader { proxy in
                            let verticalInset: CGFloat = 16
                            let horizontalInset: CGFloat = 2
                            let cardWidth = proxy.size.width - (horizontalInset * 2)
                            let cardHeight = proxy.size.height - (verticalInset * 2)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(dragBackground ?? .clear)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                                ZStack {
                                    if let symbol = trailingSwipeSymbol, dragPosition < 0,
                                       let action = actionFor(distance: abs(dragPosition)) {
                                        ActionWidget(
                                            systemImage: symbol,
                                            color: action.color,
                                            progress: min(abs(dragPosition) / SwipeConstants.level1, 1.0),
                                            isActive: abs(dragPosition) >= SwipeConstants.level1
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                        .padding(.trailing, horizontalInset + 20)
                                    }
                                }
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    .transaction { transaction in
                        transaction.disablesAnimations = true
                    }
                    .buttonStyle(EmptyButtonStyle())
        } else {
            content
        }
    }
    
    private func updateSwipeState(for position: CGFloat) {
        // Only respond to right-side (negative) drag positions
        let pos = -position // work with positive distance for trailing side
        if position >= 0 {
            // Ignore left swipes entirely to avoid back gesture conflicts
            prevDragPosition = position
            draggingPreviewNone()
            return
        }

        // Determine which level we're in and update symbol/color
        if pos >= SwipeConstants.level4 {
            updateTrailingSwipe(
                symbol: (trailingAction4 ?? trailingAction3 ?? trailingAction2 ?? trailingAction1)?.symbol.fillName,
                color: (trailingAction4 ?? trailingAction3 ?? trailingAction2 ?? trailingAction1)?.color.opacity(0.16),
                shouldVibrate: prevDragPosition > -SwipeConstants.level4 && trailingAction4 != nil
            )
        } else if pos >= SwipeConstants.level3 {
            updateTrailingSwipe(
                symbol: (trailingAction3 ?? trailingAction2 ?? trailingAction1)?.symbol.fillName,
                color: (trailingAction3 ?? trailingAction2 ?? trailingAction1)?.color.opacity(0.14),
                shouldVibrate: prevDragPosition > -SwipeConstants.level3 && trailingAction3 != nil
            )
        } else if pos >= SwipeConstants.level2 {
            updateTrailingSwipe(
                symbol: (trailingAction2 ?? trailingAction1)?.symbol.fillName,
                color: (trailingAction2 ?? trailingAction1)?.color.opacity(0.12),
                shouldVibrate: prevDragPosition > -SwipeConstants.level2 && trailingAction2 != nil
            )
        } else if pos >= SwipeConstants.level1 {
            updateTrailingSwipe(
                symbol: trailingAction1?.symbol.fillName,
                color: trailingAction1?.color.opacity(0.10),
                shouldVibrate: prevDragPosition > -SwipeConstants.level1 && trailingAction1 != nil
            )
        } else if pos > 0 {
            let opacity = min(pos / SwipeConstants.level1, 1.0) * 0.08
            updateTrailingSwipe(
                symbol: trailingAction1?.symbol.emptyName,
                color: trailingAction1?.color.opacity(opacity),
                shouldVibrate: prevDragPosition <= -SwipeConstants.level1
            )
        } else {
            draggingPreviewNone()
        }

        prevDragPosition = position
    }
    
    private func updateTrailingSwipe(symbol: String?, color: Color?, shouldVibrate: Bool) {
        trailingSwipeSymbol = symbol
        dragBackground = color
        if shouldVibrate {
            HapticManager.shared.gentleImpact()
        }
    }

    private func draggingPreviewNone() {
        trailingSwipeSymbol = trailingAction1?.symbol.emptyName
        dragBackground = nil
    }
    
    private func draggingDidEnd() {
        let finalDragPosition = prevDragPosition
        
        reset()
        
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            let pos = -finalDragPosition
            if pos >= SwipeConstants.level4 {
                await (trailingAction4 ?? trailingAction3 ?? trailingAction2 ?? trailingAction1)?.action()
            } else if pos >= SwipeConstants.level3 {
                await (trailingAction3 ?? trailingAction2 ?? trailingAction1)?.action()
            } else if pos >= SwipeConstants.level2 {
                await (trailingAction2 ?? trailingAction1)?.action()
            } else if pos >= SwipeConstants.level1 {
                await trailingAction1?.action()
            }
        }
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.25)) {
            dragPosition = .zero
            prevDragPosition = .zero
            trailingSwipeSymbol = trailingAction1?.symbol.emptyName
            dragBackground = nil
        }
    }
    
    private func shouldRespondToDragPosition(_ position: CGFloat) -> Bool {
        // Ignore left (positive) swipes entirely to avoid interfering with back gesture
        if position > 0 { return false }

        // Only respond if there is at least one trailing action configured
        if position < 0,
           trailingAction1 == nil && trailingAction2 == nil && trailingAction3 == nil && trailingAction4 == nil {
            return false
        }
        return true
    }

    private func actionFor(distance: CGFloat) -> SwipeAction? {
        if distance >= SwipeConstants.level4 {
            return trailingAction4 ?? trailingAction3 ?? trailingAction2 ?? trailingAction1
        } else if distance >= SwipeConstants.level3 {
            return trailingAction3 ?? trailingAction2 ?? trailingAction1
        } else if distance >= SwipeConstants.level2 {
            return trailingAction2 ?? trailingAction1
        } else if distance >= SwipeConstants.level1 {
            return trailingAction1
        } else {
            return trailingAction1
        }
    }
}

extension View {
    @ViewBuilder
    func customSwipeGesture(
        // Right-side only: up to four actions, increasing with distance
        right1: SwipeAction? = nil,
        right2: SwipeAction? = nil,
        right3: SwipeAction? = nil,
        right4: SwipeAction? = nil
    ) -> some View {
        modifier(
            SwipeGestureModifier(
                trailingAction1: right1,
                trailingAction2: right2,
                trailingAction3: right3,
                trailingAction4: right4
            )
        )
    }
}
