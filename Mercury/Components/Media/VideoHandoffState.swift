// VideoHandoffState.swift
// Mercury

import Foundation
import AVFoundation

/// Explicit video state for clean handoffs between inline and detail views
struct VideoHandoffState: Equatable {
    let postId: String
    let videoURL: URL
    let currentTime: TimeInterval
    let isMuted: Bool
    let player: AVPlayer
    
    init(postId: String, videoURL: URL, player: AVPlayer) {
        self.postId = postId
        self.videoURL = videoURL
        self.currentTime = player.currentTime().seconds
        self.isMuted = player.isMuted
        self.player = player
    }
    
    init(postId: String, videoURL: URL, currentTime: TimeInterval, isMuted: Bool, player: AVPlayer) {
        self.postId = postId
        self.videoURL = videoURL
        self.currentTime = currentTime
        self.isMuted = isMuted
        self.player = player
    }
    
    /// Apply this state to a player
    func applyTo(_ player: AVPlayer) {
        player.applyMuteState(muted: isMuted)
        if currentTime > 0.1 {
            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
        }
    }
    
    /// Create updated state with new time/mute values
    func updated(time: TimeInterval? = nil, muted: Bool? = nil) -> VideoHandoffState {
        VideoHandoffState(
            postId: postId,
            videoURL: videoURL,
            currentTime: time ?? currentTime,
            isMuted: muted ?? isMuted,
            player: player
        )
    }
    
    static func == (lhs: VideoHandoffState, rhs: VideoHandoffState) -> Bool {
        lhs.postId == rhs.postId &&
        lhs.videoURL == rhs.videoURL &&
        abs(lhs.currentTime - rhs.currentTime) < 0.1 &&
        lhs.player === rhs.player
    }
}
