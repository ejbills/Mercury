import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
    
    init(_ items: Any...) {
        self.items = items
    }
    
    init(items: [Any]) {
        self.items = items
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let shareItem: ShareItem
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: shareItem.items,
            applicationActivities: nil
        )
        
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}