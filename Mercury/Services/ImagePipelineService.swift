import Foundation
import Nuke
import NukeVideo

/// Configures and exposes a shared Nuke `ImagePipeline` tuned for Mercury.
/// - Enables disk caching of original data (needed for GIF playback).
/// - Sets generous memory cache and concurrent request limits.
/// - Provides a single place to tweak image loading behavior app-wide.
enum ImagePipelineService {
    static func configureSharedPipeline() {
        var config = ImagePipeline.Configuration()

        // Memory cache (in-memory decompressed images)
        config.imageCache = ImageCache(
            costLimit: 1024 * 1024 * 200, // ~200 MB
            countLimit: 1000
        )

        // Disk cache for original image data (GIF playback needs original bytes)
        if let dataCache = try? DataCache(name: "com.mercury.images.datacache") {
            dataCache.sizeLimit = 1024 * 1024 * 500 // ~500 MB
            config.dataCache = dataCache
        }

        // Concurrency & QoS
        config.isProgressiveDecodingEnabled = true
        config.isTaskCoalescingEnabled = true
        config.dataLoadingQueue.maxConcurrentOperationCount = 6
        config.imageDecodingQueue.maxConcurrentOperationCount = 6
        config.imageProcessingQueue.maxConcurrentOperationCount = 6

        // Apply
        ImagePipeline.shared = ImagePipeline(configuration: config)

        // Register NukeVideo decoder so the pipeline can decode video assets
        ImageDecoderRegistry.shared.register(ImageDecoders.Video.init)
    }
}
