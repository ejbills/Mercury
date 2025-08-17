//
//  VideoShareSheet.swift
//  Mercury
//
//  Created by AI Assistant on 8/17/25.
//

import SwiftUI
import Photos
import UIKit

struct VideoShareSheet: UIViewControllerRepresentable {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activities: [UIActivity] = []
        
        // Add custom "Save to Photos" activity
        activities.append(SaveToPhotosActivity(videoURL: videoURL))
        
        let activityVC = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: activities
        )
        
        // Exclude some default activities since we're providing custom ones
        activityVC.excludedActivityTypes = [
            .saveToCameraRoll // We're providing our own
        ]
        
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            // Auto-dismiss when sharing is complete
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

class SaveToPhotosActivity: UIActivity {
    private let videoURL: URL
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.mercury.saveToPhotos")
    }
    
    override var activityTitle: String? {
        return "Save to Photos"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "photo.badge.plus")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }
    
    override func perform() {
        Task {
            await saveVideoToPhotos()
        }
    }
    
    @MainActor
    private func saveVideoToPhotos() async {
        // Request permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            activityDidFinish(false)
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: self.videoURL)
            }
            activityDidFinish(true)
        } catch {
            print("Failed to save video to Photos: \(error)")
            activityDidFinish(false)
        }
    }
}
