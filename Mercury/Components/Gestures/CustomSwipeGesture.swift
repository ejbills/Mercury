import SwiftUI
import UIKit

// MARK: - Swipe Action Models

struct SwipeAction {
    let type: SwipeActionType
    let action: () -> Void
    
    var systemImage: String { type.systemImageName }
    var color: Color { type.color }
    var displayName: String { type.displayName }
}

struct SwipeConfiguration {
    let leftShort: SwipeAction?
    let leftLong: SwipeAction?
    let rightShort: SwipeAction?
    let rightLong: SwipeAction?
    
    let shortTriggerDistance: CGFloat = 75
    let longTriggerDistance: CGFloat = 150
    let minimumHorizontalMovement: CGFloat = 75
    let maximumVerticalMovement: CGFloat = 40
}

// MARK: - Swipe State

enum SwipeState: Equatable {
    case idle
    case swipingLeft(distance: CGFloat)
    case swipingRight(distance: CGFloat)
    case triggered
    
    var isActive: Bool {
        switch self {
        case .idle, .triggered: return false
        default: return true
        }
    }
}

// MARK: - Custom Swipe Gesture Modifier

struct SwipeGestureModifier: ViewModifier {
    let configuration: SwipeConfiguration
    let cornerRadius: CGFloat
    let onInteractionBegan: (() -> Void)?
    let onInteractionEnded: (() -> Void)?
    
    @State private var swipeState: SwipeState = .idle
    @State private var dragOffset: CGSize = .zero
    @State private var initialTouchLocation: CGPoint = .zero
    @State private var hasTriggered = false
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State private var lastThresholdLevel: Int = 0 // 0: none, 1: short, 2: long
    @State private var isSwiping = false
    
    // Helpers kept in case we want to expose current action state later
    private var currentLeftAction: SwipeAction? {
        if case .swipingLeft(let distance) = swipeState {
            if distance >= configuration.longTriggerDistance { return configuration.leftLong }
            if distance >= configuration.shortTriggerDistance { return configuration.leftShort }
        }
        return nil
    }
    private var currentRightAction: SwipeAction? {
        if case .swipingRight(let distance) = swipeState {
            if distance >= configuration.longTriggerDistance { return configuration.rightLong }
            if distance >= configuration.shortTriggerDistance { return configuration.rightShort }
        }
        return nil
    }
    
    func body(content: Content) -> some View {
        content
            // Move content with the finger so hints appear behind, not over
            .offset(x: swipeState.isActive ? dragOffset.width : 0)
            .background {
                swipeActionHints
            }
            .simultaneousGesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeState)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let horizontalMovement = abs(value.translation.width)
        let verticalMovement = abs(value.translation.height)
        
        // Only engage when horizontal dominates sufficiently; allow scroll otherwise
        if !isSwiping {
            guard horizontalMovement >= configuration.minimumHorizontalMovement,
                  horizontalMovement > verticalMovement + 8,
                  verticalMovement <= configuration.maximumVerticalMovement else {
                swipeState = .idle
                dragOffset = .zero
                lastThresholdLevel = 0
                return
            }
            // Lock into swipe interaction once threshold crossed
            isSwiping = true
            onInteractionBegan?()
        }
        
        // Update drag offset for visual feedback
        dragOffset = value.translation
        if swipeState == .idle { feedbackGenerator.prepare() }
        
        // Determine swipe direction and distance; update state and highlight feedback
        if value.translation.width > 0 {
            let distance = value.translation.width
            swipeState = .swipingRight(distance: distance)
            provideThresholdFeedback(for: distance)
        } else if value.translation.width < 0 {
            let distance = abs(value.translation.width)
            swipeState = .swipingLeft(distance: distance)
            provideThresholdFeedback(for: distance)
        } else {
            swipeState = .idle
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        defer {
            // Reset state
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                swipeState = .idle
                dragOffset = .zero
            }
            hasTriggered = false
            lastThresholdLevel = 0
            if isSwiping {
                onInteractionEnded?()
            }
            isSwiping = false
        }
        
        let horizontal = value.translation.width
        let distance = abs(horizontal)
        guard distance >= configuration.shortTriggerDistance else { return }
        
        if horizontal > 0 {
            // Swiped right: prefer long if beyond long threshold; else short
            if distance >= configuration.longTriggerDistance, let action = configuration.rightLong {
                triggerAction(action)
            } else if let action = configuration.rightShort {
                triggerAction(action)
            }
        } else if horizontal < 0 {
            // Swiped left
            if distance >= configuration.longTriggerDistance, let action = configuration.leftLong {
                triggerAction(action)
            } else if let action = configuration.leftShort {
                triggerAction(action)
            }
        }
    }

    private func provideThresholdFeedback(for distance: CGFloat) {
        let level: Int
        if distance >= configuration.longTriggerDistance {
            level = 2
        } else if distance >= configuration.shortTriggerDistance {
            level = 1
        } else {
            level = 0
        }
        if level > lastThresholdLevel {
            feedbackGenerator.impactOccurred(intensity: level == 2 ? 1.0 : 0.5)
            lastThresholdLevel = level
        } else if level < lastThresholdLevel {
            // Went back below a threshold; allow feedback again if re-crossed
            lastThresholdLevel = level
        }
    }
    
    private func triggerAction(_ action: SwipeAction) {
        guard !hasTriggered else { return }
        
        hasTriggered = true
        feedbackGenerator.impactOccurred()
        
        // Execute action with slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            action.action()
        }
        
        // Visual feedback
        withAnimation(.easeOut(duration: 0.2)) {
            swipeState = .triggered
        }
    }
    
    @ViewBuilder
    private var swipeActionHints: some View {
        GeometryReader { proxy in
            ZStack {
                // Badge for selected action (icon with its own compact background)
                if let selected = selectedAction {
                    ActionBadge(action: selected.action,
                                progress: selected.progress,
                                availableHeight: proxy.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                        .padding(alignment == .leading ? .leading : .trailing, 4)
                        .transition(.move(edge: alignment == .leading ? .leading : .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: swipeState)
        }
        .allowsHitTesting(false)
    }

    private var alignment: Alignment {
        switch swipeState {
        case .swipingRight: return .leading
        case .swipingLeft: return .trailing
        default: return .leading
        }
    }

    private var revealedWidth: CGFloat {
        switch swipeState {
        case .swipingRight(let d): return d
        case .swipingLeft(let d): return d
        default: return 0
        }
    }
    
    // Note: background stripe removed; using compact background behind icon instead

    // Selected action for current swipe direction/distance
    private var selectedAction: (action: SwipeAction, isLong: Bool, progress: CGFloat)? {
        switch swipeState {
        case .swipingRight(let distance):
            if distance >= configuration.longTriggerDistance, let a = configuration.rightLong {
                return (a, true, min(distance / configuration.longTriggerDistance, 1.0))
            } else if distance >= configuration.shortTriggerDistance, let a = configuration.rightShort {
                return (a, false, min(distance / configuration.shortTriggerDistance, 1.0))
            }
        case .swipingLeft(let distance):
            if distance >= configuration.longTriggerDistance, let a = configuration.leftLong {
                return (a, true, min(distance / configuration.longTriggerDistance, 1.0))
            } else if distance >= configuration.shortTriggerDistance, let a = configuration.leftShort {
                return (a, false, min(distance / configuration.shortTriggerDistance, 1.0))
            }
        default:
            break
        }
        return nil
    }
}

// MARK: - Swipe Action Hint View

struct SwipeActionHint: View {
    let action: SwipeAction
    let isActive: Bool
    let progress: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: action.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(action.color.opacity(isActive ? 1.0 : 0.6))
                        .scaleEffect(isActive ? 1.1 : 0.8 + (progress * 0.2))
                )
                .shadow(color: action.color.opacity(0.3), radius: isActive ? 8 : 4, x: 0, y: 2)
            
            Text(action.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(action.color)
                .opacity(0.8 + (progress * 0.2))
        }
        .scaleEffect(0.7 + (progress * 0.3))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.easeOut(duration: 0.2), value: progress)
    }
}

// MARK: - View Extension

private struct ActionBadge: View {
    let action: SwipeAction
    let progress: CGFloat
    let availableHeight: CGFloat
    
    var body: some View {
        // Target sizes
        let targetCircle: CGFloat = 30
        let targetPadding: CGFloat = 16 // around circle
        let desiredBG: CGFloat = targetCircle + (targetPadding * 2)
        // Keep at least 8pt margins vertically inside the card
        let maxBG = max(40, availableHeight - 16)
        let bg = min(desiredBG, maxBG)
        // Ensure circle fits within bg with at least 8pt padding if space is tight
        let circle = min(targetCircle, bg - 16)
        let iconSize = min(18, circle - 12)
        
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(action.color.opacity(0.18))
                .frame(width: bg, height: bg)
            
            Circle()
                .fill(action.color)
                .frame(width: circle, height: circle)
                .overlay {
                    Image(systemName: action.systemImage)
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .shadow(color: action.color.opacity(0.25), radius: 6, x: 0, y: 2)
        .scaleEffect(0.92 + (progress * 0.08))
        .accessibilityLabel(Text(action.displayName))
    }
}

extension View {
    func customSwipeGesture(
        leftShort: SwipeAction? = nil,
        leftLong: SwipeAction? = nil,  
        rightShort: SwipeAction? = nil,
        rightLong: SwipeAction? = nil,
        cornerRadius: CGFloat = 16,
        onInteractionBegan: (() -> Void)? = nil,
        onInteractionEnded: (() -> Void)? = nil
    ) -> some View {
        let configuration = SwipeConfiguration(
            leftShort: leftShort,
            leftLong: leftLong,
            rightShort: rightShort, 
            rightLong: rightLong
        )
        
        return self.modifier(
            SwipeGestureModifier(
                configuration: configuration,
                cornerRadius: cornerRadius,
                onInteractionBegan: onInteractionBegan,
                onInteractionEnded: onInteractionEnded
            )
        )
    }
}
