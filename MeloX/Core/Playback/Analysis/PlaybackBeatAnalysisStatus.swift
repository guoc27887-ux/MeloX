import Foundation

nonisolated enum PlaybackBeatAnalysisStatus:
    Equatable,
    Sendable
{
    case idle
    case analyzing
    case ready(bpm: Double, confidence: Double)
    case failed(message: String)
}
