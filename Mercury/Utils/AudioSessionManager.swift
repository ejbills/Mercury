import AVFoundation

enum AudioSessionManager {
    /// Configure the app's audio session to avoid interrupting other audio sources.
    /// Uses `.ambient` with `.mixWithOthers` so inline videos do not stop
    /// background audio (e.g., Music, Podcasts), even when local video is muted.
    static func configureIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Only reconfigure if the category isn't already set as desired
            if session.category != .ambient || !session.categoryOptions.contains(.mixWithOthers) {
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            }
            if !session.isOtherAudioPlaying { // Activate without disrupting current audio
                try session.setActive(true, options: [])
            } else {
                // When other audio is already playing, activate in a non-disruptive way
                try? session.setActive(true, options: [.notifyOthersOnDeactivation])
            }
        } catch {
            // If audio session configuration fails, we silently ignore.
        }
    }
}

