import Foundation

nonisolated struct PlaybackBeatDebugSnapshot:
    Equatable,
    Sendable
{
    let playbackTime: TimeInterval
    let regionStart: TimeInterval
    let regionEnd: TimeInterval
    let frameIndex: Int?
    let frameCount: Int
    let isInsideAnalysisRegion: Bool

    let bpm: Double
    let confidence: Double
    let decodedBeatCount: Int
    let decodedDownbeatCount: Int
    let beatOrdinal: Int?
    let beatInBar: Int?
    let secondsSinceBeat: TimeInterval?

    let recentBeatActivation: Double
    let recentDownbeatActivation: Double
    let currentBeatActivation: Double
    let currentDownbeatActivation: Double
    let normalizedOnsetActivation: Double
    let recentVignetteTriggerActivation:
        Double
    let maximumBeatActivation: Double
    let maximumDownbeatActivation: Double
    let nonzeroBeatFrameCount: Int
    let nonzeroDownbeatFrameCount: Int
    let featureStatistics: BeatNetFeatureStatistics
    let finalAllZeroSegmentCount: Int
    let analyzedSegmentCount: Int
    let jointVignetteGateIsActive: Bool
    let appliedVignettePulse: Double
    let vignettePulse: Double
}
