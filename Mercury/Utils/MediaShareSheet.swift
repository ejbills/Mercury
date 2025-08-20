//
//  MediaShareSheet.swift
//  Mercury
//
//

import SwiftUI
import Photos
import UIKit

struct MediaShareSheet: UIViewControllerRepresentable {
    let post: RedditPost
    let mediaURL: URL?
    let mediaURLs: [URL]?
    @Environment(\.dismiss) private var dismiss
    
    init(post: RedditPost, mediaURL: URL?) {
        self.post = post
        self.mediaURL = mediaURL
        self.mediaURLs = nil
    }
    
    init(post: RedditPost, mediaURLs: [URL]) {
        self.post = post
        self.mediaURL = nil
        self.mediaURLs = mediaURLs
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activityItems: [Any] = []
        var activities: [UIActivity] = []
        
        // Add the media file(s) if available
        if let mediaURLs = mediaURLs {
            // Multiple URLs for galleries
            activityItems.append(contentsOf: mediaURLs)
            activities.append(SaveMultipleImagesToPhotosActivity(fileURLs: mediaURLs))
        } else if let mediaURL = mediaURL {
            // Single URL for individual media
            activityItems.append(mediaURL)
            
            // Add custom "Save to Photos" activity based on file type
            let fileExtension = mediaURL.pathExtension.lowercased()
            
            if fileExtension == "mp4" || fileExtension == "mov" || fileExtension == "webm" {
                // Video files
                activities.append(SaveVideoToPhotosActivity(fileURL: mediaURL))
            } else {
                // Image files (including GIFs which we'll handle as images with animation)
                activities.append(SaveImageToPhotosActivity(fileURL: mediaURL))
            }
        }
        
        // Always include the post permalink as text (this is the main thing being shared)
        activityItems.append(post.permalinkURL)
        
        // Add post title for context
        if !post.title.isEmpty {
            activityItems.append("\(post.title)")
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: activities
        )
        
        // Exclude default save to camera roll since we provide custom ones
        activityVC.excludedActivityTypes = [
            .saveToCameraRoll
        ]
        
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            // Auto-dismiss when sharing is complete
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Save to Photos Activities

class SaveImageToPhotosActivity: UIActivity {
    private let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.mercury.saveImageToPhotos")
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
            await saveImageToPhotos()
        }
    }
    
    @MainActor
    private func saveImageToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            activityDidFinish(false)
            return
        }
        
        do {
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if fileExtension == "gif" {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: self.fileURL)
                }
            } else {
                // For regular images (jpg, png, etc.)
                let imageData = try Data(contentsOf: fileURL)
                guard let image = UIImage(data: imageData) else {
                    activityDidFinish(false)
                    return
                }
                
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }
            }
            
            activityDidFinish(true)
        } catch {
            activityDidFinish(false)
        }
    }
}

class SaveVideoToPhotosActivity: UIActivity {
    private let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.mercury.saveVideoToPhotos")
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
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            activityDidFinish(false)
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: self.fileURL)
            }
            activityDidFinish(true)
        } catch {
            activityDidFinish(false)
        }
    }
}

class SaveMultipleImagesToPhotosActivity: UIActivity {
    private let fileURLs: [URL]
    
    init(fileURLs: [URL]) {
        self.fileURLs = fileURLs
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.mercury.saveMultipleImagesToPhotos")
    }
    
    override var activityTitle: String? {
        return "Save All to Photos"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "photo.stack.fill")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return !fileURLs.isEmpty
    }
    
    override func perform() {
        Task {
            await saveImagesToPhotos()
        }
    }
    
    @MainActor
    private func saveImagesToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            activityDidFinish(false)
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for fileURL in self.fileURLs {
                    do {
                        let imageData = try Data(contentsOf: fileURL)
                        if let image = UIImage(data: imageData) {
                            PHAssetCreationRequest.creationRequestForAsset(from: image)
                        }
                    } catch {
                        print("Failed to load image from \(fileURL): \(error)")
                    }
                }
            }
            activityDidFinish(true)
        } catch {
            print("Failed to save images to Photos: \(error)")
            activityDidFinish(false)
        }
    }
}
