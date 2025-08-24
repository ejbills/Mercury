import UIKit

@MainActor
final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {}
    
    func gentleImpact() {
        impactGenerator.impactOccurred(intensity: 0.3)
    }
    
    func firmerImpact() {
        impactGenerator.impactOccurred(intensity: 0.8)
    }
    
    func softImpact() {
        impactGenerator.impactOccurred(intensity: 0.5)
    }
    
    func success() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    func error() {
        notificationGenerator.notificationOccurred(.error)
    }
}