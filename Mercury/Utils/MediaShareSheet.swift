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
    
    private func saveImageToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            await MainActor.run { activityDidFinish(false) }
            return
        }

        do {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "gif" {
                // Ensure we have a local file to hand to Photos for GIFs
                let localURL: URL
                if fileURL.isFileURL {
                    localURL = fileURL
                } else {
                    localURL = try await Self.downloadToTemporaryFile(from: fileURL, suggestedExtension: "gif")
                }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: localURL)
                }
            } else {
                // Load image data off the main thread (supports remote and local URLs)
                let data = try await Self.loadData(from: fileURL)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { activityDidFinish(false) }
                    return
                }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }
            }
            await MainActor.run { activityDidFinish(true) }
        } catch {
            await MainActor.run { activityDidFinish(false) }
        }
    }

    // MARK: - Helpers
     static func loadData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        } else {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    }

    private static func downloadToTemporaryFile(from url: URL, suggestedExtension: String? = nil) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: url)
        let ext = suggestedExtension ?? url.pathExtension
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext.isEmpty ? "bin" : ext)
        try data.write(to: tmp)
        return tmp
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
    
    private func saveImagesToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            await MainActor.run { activityDidFinish(false) }
            return
        }

        do {
            // Load images sequentially off the main thread
            var images: [UIImage] = []
            images.reserveCapacity(fileURLs.count)
            for url in fileURLs {
                do {
                    let data = try await SaveImageToPhotosActivity.loadData(from: url)
                    if let img = UIImage(data: data) { images.append(img) }
                } catch {
                    print("Failed to load image from \(url): \(error)")
                }
            }
            // Save each image
            for img in images {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: img)
                }
            }
            await MainActor.run { activityDidFinish(true) }
        } catch {
            print("Failed to save images to Photos: \(error)")
            await MainActor.run { activityDidFinish(false) }
        }
    }
}
