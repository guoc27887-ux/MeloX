import Foundation

/// Maps playback time to the horizontal lyric highlight front.
///
/// Regular glyphs track their timing continuously. A long-held glyph reveals
/// most of itself quickly, keeps drifting near its trailing edge, then completes
/// shortly before the next glyph. This avoids leaving a slow syllable visibly
/// split or frozen for most of its duration.
enum LyricHighlightRevealProgress {
    static func progress(
        playbackTime: TimeInterval,
        timing: LyricTimingTextAttribute,
        detectionMode: LyricsLongSyllableDetectionMode,
        durationThreshold: TimeInterval,
        lineFinishProgressAnimationDuration: TimeInterval? = nil
    ) -> Double {
        let finishDuration = resolvedFinishDuration(
            lineFinishProgressAnimationDuration
        )
        let duration = timing.endTime - timing.startTime
        let rawProgress = playedProgress(
            playbackTime: playbackTime,
            timing: timing,
            duration: duration
        )
        let regularProgress = smootherStep(rawProgress)
        guard duration > Metrics.attackDuration + finishDuration else {
            return regularProgress
        }

        guard LyricLongToneEmphasis.isLongTone(
            timing: timing,
            detectionMode: detectionMode,
            durationThreshold: durationThreshold
        ) else {
            return regularProgress
        }

        let elapsed = max(playbackTime - timing.startTime, 0)
        let attackProgress = smootherStep(
            elapsed / Metrics.attackDuration
        )
        let releaseStartTime = timing.endTime - finishDuration
        let releaseProgress = smootherStep(
            (playbackTime - releaseStartTime) / finishDuration
        )
        return unitProgress(
            Metrics.attackContribution * attackProgress
                + Metrics.continuousContribution * rawProgress
                + Metrics.releaseContribution * releaseProgress
        )
    }

    private static func resolvedFinishDuration(
        _ duration: TimeInterval?
    ) -> TimeInterval {
        guard let duration, duration.isFinite, duration > 0 else {
            return Metrics.releaseDuration
        }
        return duration
    }

    private static func playedProgress(
        playbackTime: TimeInterval,
        timing: LyricTimingTextAttribute,
        duration: TimeInterval
    ) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }
        guard duration > 0 else { return 1 }
        return unitProgress(
            (playbackTime - timing.startTime) / duration
        )
    }

    private static func smootherStep(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private static func unitProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private extension LyricHighlightRevealProgress {
    enum Metrics {
        static let attackDuration: TimeInterval = 0.3
        static let releaseDuration: TimeInterval = 0.16
        static let attackContribution = 0.82
        static let continuousContribution = 0.08
        static let releaseContribution = 0.1
    }
}
