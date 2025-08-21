import SwiftUI

struct CopiedToast: View {
    let isShowing: Bool
    let message: String
    let position: Position
    
    enum Position {
        case top
        case center
        case bottom
    }
    
    init(isShowing: Bool, message: String = "Copied!", position: Position = .top) {
        self.isShowing = isShowing
        self.message = message
        self.position = position
    }
    
    var body: some View {
        if isShowing {
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowing)
        }
    }
}

struct InlineToast: View {
    let isShowing: Bool
    let message: String
    
    init(isShowing: Bool, message: String = "Copied!") {
        self.isShowing = isShowing
        self.message = message
    }
    
    var body: some View {
        if isShowing {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowing)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CopiedToast(isShowing: true)
        InlineToast(isShowing: true)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.blue.gradient)
}