import SwiftUI

struct ActionWidget: View {
    private let systemImage: String
    private let color: Color
    private let progress: CGFloat
    private let isActive: Bool
    
    init(systemImage: String, color: Color, progress: CGFloat, isActive: Bool) {
        self.systemImage = systemImage
        self.color = color
        self.progress = progress
        self.isActive = isActive
    }
    
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: isActive ? .bold : .medium, design: .rounded))
            .foregroundStyle(iconColor)
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0), value: isActive)
            .animation(.easeOut(duration: 0.2), value: progress)
    }
    
    private var iconColor: Color {
        let intensity = isActive ? 1.0 : (0.6 + progress * 0.4)
        return color.opacity(intensity)
    }
    
    private var iconScale: CGFloat {
        isActive ? 1.15 : 0.85 + progress * 0.15
    }
    
    private var iconOpacity: Double {
        0.7 + progress * 0.3
    }
}