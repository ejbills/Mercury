import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        // Avoid deprecated tint overrides on iOS 26+
        if #unavailable(iOS 26.0) {
            safari.preferredControlTintColor = UIColor.systemBlue
            safari.preferredBarTintColor = UIColor.systemBackground
        }
        
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

#Preview {
    SafariView(url: URL(string: "https://apple.com")!)
}
