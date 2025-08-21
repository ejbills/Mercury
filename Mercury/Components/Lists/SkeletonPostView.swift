import SwiftUI

struct SkeletonPostView: View {
    @State private var isAnimating = false
    
    var body: some View {
        MaterialCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(skeletonGradient)
                        .frame(width: 20, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 80, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 60, height: 12)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 30, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 280, height: 16)
                    
                    if Bool.random() {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(skeletonGradient)
                            .frame(width: 200, height: 16)
                    }
                }
                
                Group {
                    if Bool.random() {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonGradient)
                            .frame(height: CGFloat.random(in: 200...350))
                    } else if Bool.random() {
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(skeletonGradient)
                                .frame(height: 14)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(skeletonGradient)
                                .frame(width: 320, height: 14)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(skeletonGradient)
                                .frame(width: 250, height: 14)
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(skeletonGradient)
                            .frame(width: 12, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(skeletonGradient)
                            .frame(width: 40, height: 12)
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(skeletonGradient)
                            .frame(width: 12, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(skeletonGradient)
                            .frame(width: 25, height: 12)
                    }
                    
                    Spacer()
                    
                    if Bool.random() {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(skeletonGradient)
                            .frame(width: 50, height: 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .redacted(reason: .placeholder)
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating.toggle()
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray5),
                Color(.systemGray4),
                Color(.systemGray5)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonPostView()
            }
        }
        .padding(12)
    }
}