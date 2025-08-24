import SwiftUI
import Defaults

private enum SwipeConstants {
    static let shortSwipeDragMin: CGFloat = 100
    static let longSwipeDragMin: CGFloat = 140
}

struct SwipeGestureModifier: ViewModifier {
    @GestureState private var dragState: CGFloat = .zero
    @State private var dragPosition: CGFloat = .zero
    @State private var prevDragPosition: CGFloat = .zero
    @State private var dragBackground: Color?
    @State private var leadingSwipeSymbol: String?
    @State private var trailingSwipeSymbol: String?
    
    private let primaryLeadingAction: SwipeAction?
    private let secondaryLeadingAction: SwipeAction?
    private let primaryTrailingAction: SwipeAction?
    private let secondaryTrailingAction: SwipeAction?
    
    @Default(.swipeActionsEnabled) private var swipeActionsEnabled
    
    init(primaryLeadingAction: SwipeAction?,
         secondaryLeadingAction: SwipeAction?,
         primaryTrailingAction: SwipeAction?,
         secondaryTrailingAction: SwipeAction?
    ) {
        assert(primaryLeadingAction != nil || secondaryLeadingAction == nil,
               "Secondary leading action requires primary leading action")
        assert(primaryTrailingAction != nil || secondaryTrailingAction == nil, 
               "Secondary trailing action requires primary trailing action")
        
        self.primaryLeadingAction = primaryLeadingAction
        self.secondaryLeadingAction = secondaryLeadingAction
        self.primaryTrailingAction = primaryTrailingAction
        self.secondaryTrailingAction = secondaryTrailingAction
        
        _leadingSwipeSymbol = State(initialValue: primaryLeadingAction?.symbol.emptyName)
        _trailingSwipeSymbol = State(initialValue: primaryTrailingAction?.symbol.emptyName)
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
                                if dragState != .zero || value.location.x > 70 {
                                    state = value.translation.width
                                }
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
                                    if let symbol = leadingSwipeSymbol, dragPosition > 0,
                                       let action = dragPosition >= SwipeConstants.longSwipeDragMin ? secondaryLeadingAction ?? primaryLeadingAction : primaryLeadingAction {
                                        ActionWidget(
                                            systemImage: symbol,
                                            color: action.color,
                                            progress: min(dragPosition / SwipeConstants.shortSwipeDragMin, 1.0),
                                            isActive: dragPosition >= SwipeConstants.shortSwipeDragMin
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .padding(.leading, horizontalInset + 20)
                                    }
                                    
                                    if let symbol = trailingSwipeSymbol, dragPosition < 0,
                                       let action = abs(dragPosition) >= SwipeConstants.longSwipeDragMin ? secondaryTrailingAction ?? primaryTrailingAction : primaryTrailingAction {
                                        ActionWidget(
                                            systemImage: symbol,
                                            color: action.color,
                                            progress: min(abs(dragPosition) / SwipeConstants.shortSwipeDragMin, 1.0),
                                            isActive: abs(dragPosition) >= SwipeConstants.shortSwipeDragMin
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
        switch position {
        case let pos where pos <= -SwipeConstants.longSwipeDragMin:
            updateTrailingSwipe(
                symbol: secondaryTrailingAction?.symbol.fillName ?? primaryTrailingAction?.symbol.fillName,
                color: (secondaryTrailingAction?.color ?? primaryTrailingAction?.color)?.opacity(0.16),
                shouldVibrate: prevDragPosition > -SwipeConstants.longSwipeDragMin && secondaryTrailingAction != nil
            )
        case let pos where pos <= -SwipeConstants.shortSwipeDragMin:
            updateTrailingSwipe(
                symbol: primaryTrailingAction?.symbol.fillName,
                color: primaryTrailingAction?.color.opacity(0.12),
                shouldVibrate: prevDragPosition > -SwipeConstants.shortSwipeDragMin || prevDragPosition <= -SwipeConstants.longSwipeDragMin
            )
        case let pos where pos < 0:
            let opacity = min(abs(pos) / SwipeConstants.shortSwipeDragMin, 1.0) * 0.08
            updateTrailingSwipe(
                symbol: primaryTrailingAction?.symbol.emptyName,
                color: primaryTrailingAction?.color.opacity(opacity),
                shouldVibrate: prevDragPosition <= -SwipeConstants.shortSwipeDragMin
            )
        case let pos where pos < SwipeConstants.shortSwipeDragMin:
            let opacity = min(pos / SwipeConstants.shortSwipeDragMin, 1.0) * 0.08
            updateLeadingSwipe(
                symbol: primaryLeadingAction?.symbol.emptyName,
                color: primaryLeadingAction?.color.opacity(opacity),
                shouldVibrate: prevDragPosition >= SwipeConstants.shortSwipeDragMin
            )
        case let pos where pos < SwipeConstants.longSwipeDragMin:
            updateLeadingSwipe(
                symbol: primaryLeadingAction?.symbol.fillName,
                color: primaryLeadingAction?.color.opacity(0.12),
                shouldVibrate: prevDragPosition < SwipeConstants.shortSwipeDragMin || prevDragPosition >= SwipeConstants.longSwipeDragMin
            )
        default:
            updateLeadingSwipe(
                symbol: secondaryLeadingAction?.symbol.fillName ?? primaryLeadingAction?.symbol.fillName,
                color: (secondaryLeadingAction?.color ?? primaryLeadingAction?.color)?.opacity(0.16),
                shouldVibrate: prevDragPosition < SwipeConstants.longSwipeDragMin && secondaryLeadingAction != nil
            )
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
    
    private func updateLeadingSwipe(symbol: String?, color: Color?, shouldVibrate: Bool) {
        leadingSwipeSymbol = symbol
        dragBackground = color
        if shouldVibrate {
            HapticManager.shared.gentleImpact()
        }
    }
    
    private func draggingDidEnd() {
        let finalDragPosition = prevDragPosition
        
        reset()
        
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            switch finalDragPosition {
            case let pos where pos < -SwipeConstants.longSwipeDragMin:
                let action = secondaryTrailingAction ?? primaryTrailingAction
                await action?.action()
            case let pos where pos < -SwipeConstants.shortSwipeDragMin:
                await primaryTrailingAction?.action()
            case let pos where pos > SwipeConstants.longSwipeDragMin:
                let action = secondaryLeadingAction ?? primaryLeadingAction
                await action?.action()
            case let pos where pos > SwipeConstants.shortSwipeDragMin:
                await primaryLeadingAction?.action()
            default:
                break
            }
        }
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.25)) {
            dragPosition = .zero
            prevDragPosition = .zero
            leadingSwipeSymbol = primaryLeadingAction?.symbol.emptyName
            trailingSwipeSymbol = primaryTrailingAction?.symbol.emptyName
            dragBackground = nil
        }
    }
    
    private func shouldRespondToDragPosition(_ position: CGFloat) -> Bool {
        if position > 0, primaryLeadingAction == nil {
            return false
        }
        
        if position < 0, primaryTrailingAction == nil {
            return false
        }
        
        return true
    }
}

extension View {
    @ViewBuilder
    func customSwipeGesture(
        leftShort: SwipeAction? = nil,
        leftLong: SwipeAction? = nil,  
        rightShort: SwipeAction? = nil,
        rightLong: SwipeAction? = nil
    ) -> some View {
        modifier(
            SwipeGestureModifier(
                primaryLeadingAction: leftShort,
                secondaryLeadingAction: leftLong,
                primaryTrailingAction: rightShort,
                secondaryTrailingAction: rightLong
            )
        )
    }
}
