//
//  MediaDownloadService.swift
//  Mercury
//
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit

/// Downloads Reddit media (images, GIFs, videos) with progress tracking.
final class MediaDownloadService {
    struct DownloadOptions {
        let preferredFilename: String?
        let onProgress: ((Double) -> Void)?
        
        init(preferredFilename: String? = nil, onProgress: ((Double) -> Void)? = nil) {
            self.preferredFilename = preferredFilename
            self.onProgress = onProgress
        }
    }
    
    enum MediaType {
        case image
        case gif
        case video
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noMediaSources
        case unsupported
        case network
        case io
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .noMediaSources: return "No downloadable media sources found"
            case .unsupported: return "Unsupported or protected media"
            case .network: return "Network error during download"
            case .io: return "File I/O error during download"
            case .invalidURL: return "Invalid media URL"
            }
        }
    }
    
    // MARK: - Public API
    
    func download(post: RedditPost, options: DownloadOptions? = nil) async throws -> URL {
        let downloadOptions = options ?? DownloadOptions()
        
        switch post.postType {
        case .image:
            return try await downloadImage(post: post, options: downloadOptions)
        case .gif:
            return try await downloadGif(post: post, options: downloadOptions)
        case .video:
            return try await downloadVideo(post: post, options: downloadOptions)
        case .text, .link, .youtube:
            throw Error.unsupported
        case .gallery:
            return try await downloadGallery(post: post, options: downloadOptions)
        }
    }
    
    // MARK: - Image Download
    
    private func downloadImage(post: RedditPost, options: DownloadOptions) async throws -> URL {
        guard let imageURL = post.imageURL else {
            throw Error.noMediaSources
        }
        
        // Determine file extension based on URL
        let url = URL(string: imageURL)
        let pathExtension = url?.pathExtension.lowercased()
        let fileExtension: String
        
        if let ext = pathExtension, !ext.isEmpty && ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
            fileExtension = ext
        } else {
            // Default to jpg if we can't determine
            fileExtension = "jpg"
        }
        
        let filename = (options.preferredFilename?.isEmpty == false ? options.preferredFilename! : post.id) + ".\(fileExtension)"
        return try await downloadFile(
            from: imageURL,
            filename: filename,
            onProgress: options.onProgress
        )
    }
    
    // MARK: - GIF Download
    
    private func downloadGif(post: RedditPost, options: DownloadOptions) async throws -> URL {
        guard let gifURL = post.gifURL else {
            throw Error.noMediaSources
        }
        
        // Check if it's a Reddit video that's marked as GIF
        if let media = post.media ?? post.secureMedia,
           let redditVideo = media.redditVideo,
           redditVideo.isGif {
            // Use video download for Reddit GIFs (they're actually MP4s)
            return try await downloadVideo(post: post, options: options)
        }
        
        // For actual GIF files
        let filename = (options.preferredFilename?.isEmpty == false ? options.preferredFilename! : post.id) + ".gif"
        return try await downloadFile(
            from: gifURL,
            filename: filename,
            onProgress: options.onProgress
        )
    }
    
    // MARK: - Gallery Download
    
    private func downloadGallery(post: RedditPost, options: DownloadOptions) async throws -> URL {
        let galleryImages = post.galleryImages
        guard !galleryImages.isEmpty else {
            throw Error.noMediaSources
        }
        
        // For single gallery download, just download the first image
        // For multiple gallery downloads, use downloadAllGalleryImages
        let firstImage = galleryImages[0]
        let filename = (options.preferredFilename?.isEmpty == false ? options.preferredFilename! : post.id) + "_1.jpg"
        return try await downloadFile(
            from: firstImage.url,
            filename: filename,
            onProgress: options.onProgress
        )
    }
    
    // Download all images in a gallery and return URLs
    func downloadAllGalleryImages(post: RedditPost, options: DownloadOptions? = nil) async throws -> [URL] {
        let downloadOptions = options ?? DownloadOptions()
        let galleryImages = post.galleryImages
        guard !galleryImages.isEmpty else {
            throw Error.noMediaSources
        }
        
        let totalImages = galleryImages.count
        var downloadedURLs: [URL] = []
        
        // Download all images concurrently
        try await withThrowingTaskGroup(of: (Int, URL).self) { group in
            for (index, galleryImage) in galleryImages.enumerated() {
                group.addTask {
                    let filename = (downloadOptions.preferredFilename?.isEmpty == false ? downloadOptions.preferredFilename! : post.id) + "_\(index + 1).jpg"
                    let imageURL = try await self.downloadFile(
                        from: galleryImage.url,
                        filename: filename,
                        onProgress: { progress in
                            // Calculate overall progress
                            let imageProgress = progress / Double(totalImages)
                            let baseProgress = Double(index) / Double(totalImages)
                            let totalProgress = baseProgress + imageProgress
                            downloadOptions.onProgress?(totalProgress)
                        }
                    )
                    return (index, imageURL)
                }
            }
            
            // Collect results in order
            for try await (_, url) in group {
                downloadedURLs.append(url)
            }
        }
        
        downloadOptions.onProgress?(1.0)
        return downloadedURLs.sorted { _, _ in true } // Keep original order
    }
    
    // MARK: - Video Download
    
    private func downloadVideo(post: RedditPost, options: DownloadOptions) async throws -> URL {
        // Use existing video download logic
        let videoService = VideoDownloadService()
        return try await videoService.download(post: post, options: VideoDownloadService.DownloadOptions(
            preferredFilename: options.preferredFilename,
            onProgress: options.onProgress
        ))
    }
    
    // MARK: - Generic File Download
    
    private func downloadFile(from urlString: String, filename: String, onProgress: ((Double) -> Void)?) async throws -> URL {
        guard let url = URL(string: urlString) else { 
            throw Error.invalidURL 
        }
        
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destinationURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            var progressObserver: NSKeyValueObservation?
            
            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                progressObserver?.invalidate()
                
                if error != nil {
                    continuation.resume(throwing: Error.network)
                    return
                }
                
                guard let tempURL = tempURL,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: Error.network)
                    return
                }
                
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    
                    // Set current timestamp on the file
                    let currentDate = Date()
                    try? FileManager.default.setAttributes([
                        .creationDate: currentDate,
                        .modificationDate: currentDate
                    ], ofItemAtPath: destinationURL.path)
                    
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: Error.io)
                }
            }
            
            // Add progress observation
            progressObserver = task.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    onProgress?(progress.fractionCompleted)
                }
            }
            
            task.resume()
        }
    }
}
