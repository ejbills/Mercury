//
//  VideoDownloadService.swift
//  Mercury
//
//

import Foundation
import AVFoundation
import CoreMedia

/// Downloads Reddit videos with audio support when available.
final class VideoDownloadService {
    struct DownloadOptions {
        let preferredFilename: String?
        let onProgress: ((Double) -> Void)?
        
        init(preferredFilename: String? = nil, onProgress: ((Double) -> Void)? = nil) {
            self.preferredFilename = preferredFilename
            self.onProgress = onProgress
        }
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noVideoSources
        case unsupported
        case network
        case io
        
        var errorDescription: String? {
            switch self {
            case .noVideoSources: return "No downloadable video sources found"
            case .unsupported: return "Unsupported or protected stream"
            case .network: return "Network error during download"
            case .io: return "File I/O error during download"
            }
        }
    }
    
    func download(post: RedditPost, options: DownloadOptions? = nil) async throws -> URL {
        let downloadOptions = options ?? DownloadOptions()
        if let redditVideo = (post.media ?? post.secureMedia)?.redditVideo {
            if let fallbackURL = redditVideo.fallbackUrl {
                if let merged = try? await downloadAndMergeRedditAudioVideo(videoURL: fallbackURL, preferredFilename: downloadOptions.preferredFilename, onProgress: downloadOptions.onProgress) {
                    return merged
                }
                return try await downloadFile(from: fallbackURL, preferredFilename: downloadOptions.preferredFilename, onProgress: downloadOptions.onProgress)
            }
        }
        
        if let urlString = post.videoURL, urlString.lowercased().hasSuffix(".mp4") {
            return try await downloadFile(from: urlString, preferredFilename: downloadOptions.preferredFilename, onProgress: downloadOptions.onProgress)
        }
        
        if let urlString = post.url, urlString.contains("v.redd.it") {
            let cleaned = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
            let candidates = ["/DASH_1080.mp4", "/DASH_720.mp4", "/DASH_480.mp4", "/DASH_360.mp4"].map { cleaned + $0 }
            
            for candidate in candidates {
                if let url = URL(string: candidate) {
                    var req = URLRequest(url: url)
                    req.httpMethod = "HEAD"
                    if let (_, resp) = try? await NetworkManager.shared.session.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 {
                        if let merged = try? await downloadAndMergeRedditAudioVideo(videoURL: candidate, preferredFilename: downloadOptions.preferredFilename, onProgress: downloadOptions.onProgress) {
                            return merged
                        }
                        return try await downloadFile(from: candidate, preferredFilename: downloadOptions.preferredFilename, onProgress: downloadOptions.onProgress)
                    }
                }
            }
        }
        
        throw Error.noVideoSources
    }
    
    private func downloadFile(from urlString: String, preferredFilename: String?, onProgress: ((Double) -> Void)?) async throws -> URL {
        guard let url = URL(string: urlString) else { throw Error.network }
        
        let filename = (preferredFilename?.isEmpty == false ? preferredFilename! : UUID().uuidString) + ".mp4"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destinationURL)
        return try await withCheckedThrowingContinuation { continuation in
            var progressObserver: NSKeyValueObservation?
            
            let task = NetworkManager.shared.session.downloadTask(with: url) { tempURL, response, error in
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
    
    private func downloadAndMergeRedditAudioVideo(videoURL: String, preferredFilename: String?, onProgress: ((Double) -> Void)?) async throws -> URL? {
        let baseURL = videoURL.replacingOccurrences(of: #"(v\.redd\.it/\w+/)(\w+)(\.mp4)(\?.*)?$"#, 
                                                   with: "$1", 
                                                   options: .regularExpression)
        let queryParams = videoURL.contains("?") ? String(videoURL.split(separator: "?").last!) : ""
        let queryString = queryParams.isEmpty ? "" : "?" + queryParams
        
        let audioCandidates = [
            baseURL + "DASH_AUDIO_128.mp4" + queryString,
            baseURL + "DASH_AUDIO_64.mp4" + queryString,
            baseURL + "DASH_audio.mp4" + queryString,
            baseURL + "audio.mp4" + queryString,
            baseURL + "DASH_AUDIO_128.mp4",
            baseURL + "DASH_AUDIO_64.mp4",
            baseURL + "DASH_audio.mp4",
            baseURL + "audio.mp4"
        ]
        
        var foundAudioURL: String? = nil
        
        for audioCandidate in audioCandidates {
            var audioReq = URLRequest(url: URL(string: audioCandidate)!)
            audioReq.httpMethod = "HEAD"
            
            if let audioResp = try? await NetworkManager.shared.session.data(for: audioReq).1 as? HTTPURLResponse,
               audioResp.statusCode == 200 {
                foundAudioURL = audioCandidate
                break
            }
        }
        
        guard let finalAudioURL = foundAudioURL else { return nil }
        
        let videoFile = try await downloadFile(from: videoURL, preferredFilename: nil, onProgress: { progress in
            onProgress?(progress * 0.4)
        })
        
        let audioFile = try await downloadFile(from: finalAudioURL, preferredFilename: nil, onProgress: { progress in
            onProgress?(0.4 + progress * 0.4)
        })
        
        onProgress?(0.8)
        return try await mergeAudioVideo(videoURL: videoFile, audioURL: audioFile, preferredFilename: preferredFilename)
    }
    
    private func mergeAudioVideo(videoURL: URL, audioURL: URL, preferredFilename: String?) async throws -> URL {
        let composition = AVMutableComposition()
        
        let videoAsset = AVURLAsset(url: videoURL)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        if let videoTrack = videoTracks.first, let compositionVideoTrack = compositionVideoTrack {
            let duration = try await videoAsset.load(.duration)
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        }
        
        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        if let audioTrack = audioTracks.first, let compositionAudioTrack = compositionAudioTrack {
            let duration = try await audioAsset.load(.duration)
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        }
        
        // Export merged video with current timestamp
        let filename = (preferredFilename?.isEmpty == false ? preferredFilename! : UUID().uuidString) + "_merged.mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Error.io
        }
        
        exportSession.shouldOptimizeForNetworkUse = true
        let creationDateItem = AVMutableMetadataItem()
        creationDateItem.identifier = .commonIdentifierCreationDate
        creationDateItem.value = Date() as NSDate
        
        let modificationDateItem = AVMutableMetadataItem()
        modificationDateItem.identifier = .commonIdentifierLastModifiedDate
        modificationDateItem.value = Date() as NSDate
        
        exportSession.metadata = [creationDateItem, modificationDateItem]
        
        try await exportSession.export(to: outputURL, as: .mp4)
        
        let currentDate = Date()
        try? FileManager.default.setAttributes([
            .creationDate: currentDate,
            .modificationDate: currentDate
        ], ofItemAtPath: outputURL.path)
        
        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: audioURL)
        
        return outputURL
    }
}
