import AVFoundation

enum AudioSessionManager {
    private static var observers: [NSObjectProtocol] = []
    private static var hasRegisteredObservers = false

    /// Ensure the session is configured for inline media playback without stealing audio focus.
    /// Uses `.ambient` with `.mixWithOthers` and keeps the session active so subsequent players
    /// do not start muted after an interruption or route change.
    static func configureIfNeeded(force: Bool = false) {
        runOnMainSync {
            let session = AVAudioSession.sharedInstance()
            do {
                if force || session.category != .ambient || !session.categoryOptions.contains(.mixWithOthers) {
                    try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                }
                try activate(session: session)
                registerObserversIfNeeded()
            } catch {
                #if DEBUG
                print("[AudioSession] configure error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Convenience wrapper used by players immediately before playback.
    static func ensurePlaybackSessionActive() {
        configureIfNeeded()
    }

    /// Reconfigure after a system reset or catastrophic failure.
    static func forceReconfigure() {
        configureIfNeeded(force: true)
    }

    /// Attempt to release the audio session when we no longer need it.
    static func deactivate() {
        runOnMainSync {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                #if DEBUG
                print("[AudioSession] deactivate error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private static func activate(session: AVAudioSession) throws {
        if session.isOtherAudioPlaying {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } else {
            try session.setActive(true, options: [])
        }
    }

    private static func registerObserversIfNeeded() {
        guard !hasRegisteredObservers else { return }
        hasRegisteredObservers = true

        let center = NotificationCenter.default
        let interruption = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { notification in
            handleInterruption(notification)
        }

        let servicesReset = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { _ in
            forceReconfigure()
        }

        let routeChange = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { _ in
            configureIfNeeded()
        }

        observers = [interruption, servicesReset, routeChange]
    }

    private static func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            break
        case .ended:
            configureIfNeeded()
        @unknown default:
            configureIfNeeded()
        }
    }

    private static func runOnMainSync(_ work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}
