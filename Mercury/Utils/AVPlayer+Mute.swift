// AVPlayer+Mute.swift
// Mercury

import AVFoundation

extension AVPlayer {
    /// Apply mute state consistently by setting both `isMuted` and `volume`.
    func applyMuteState(muted: Bool) {
        isMuted = muted
        volume = muted ? 0.0 : 1.0
    }
}

