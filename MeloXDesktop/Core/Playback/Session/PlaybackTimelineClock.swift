import Foundation

/// Smoothly projects playback time between actual engine samples. Every new
/// sample replaces the anchor; this type never guesses whether drift occurred.
struct PlaybackTimelineClock: Sendable {
    private var anchorPosition: TimeInterval = 0
    private var anchorDate = Date()
    private var playbackRate: Double = 0

    mutating func reanchor(
        to position: TimeInterval,
        rate: Double,
        at date: Date = Date()
    ) {
        anchorPosition = position.isFinite
            ? max(position, 0)
            : 0
        playbackRate = rate.isFinite
            ? max(rate, 0)
            : 0
        anchorDate = date
    }

    func position(
        at date: Date = Date(),
        duration: TimeInterval
    ) -> TimeInterval {
        let elapsed = max(
            date.timeIntervalSince(anchorDate),
            0
        )
        let estimated = max(
            anchorPosition + elapsed * playbackRate,
            0
        )
        guard duration.isFinite, duration > 0 else {
            return estimated
        }
        return min(estimated, duration)
    }
}
