import Foundation

nonisolated enum LyricInterludeTimingSource: Hashable, Sendable {
    /// YRC supplies an authored line or syllable end time.
    case precise

    /// LRC only supplies line starts, so the vocal tail is estimated.
    case lineSynchronized
}

nonisolated enum LyricInterludeDetectionPolicy: Hashable, Sendable {
    /// Match Music's authored-timeline path and ignore inferred LRC gaps.
    case preciseTiming

    /// Include LRC gaps whose inferred silent duration reaches the threshold.
    case automatic(minimumInferredGapDuration: TimeInterval)
}

struct LyricInterlude: Identifiable, Hashable {
    let startTime: TimeInterval
    let countdownEndTime: TimeInterval
    let precedingLyricID: LyricLine.ID?
    let followingLyricID: LyricLine.ID
    let displayBeforeLyricID: LyricLine.ID
    let timingSource: LyricInterludeTimingSource

    var id: String {
        "lyric-interlude-\(startTime)-\(displayBeforeLyricID)-\(followingLyricID)"
    }

    var isPrelude: Bool {
        precedingLyricID == nil
    }

    /// The dots begin their visual exit before the following lyric starts.
    var cueOutTime: TimeInterval {
        max(
            startTime,
            countdownEndTime
                - AppleMusicInterludeMotionProfile.iOS26_6.cueOutLeadTime
        )
    }

    var gapDuration: TimeInterval {
        max(countdownEndTime - startTime, 0)
    }
}

struct LyricInterludePlaybackPosition: Equatable {
    /// The resident 40-point row owns the indicator lifecycle. Its resolved
    /// dot presentation can already be visually empty near the lyric
    /// boundary.
    let visibleInterludeID: LyricInterlude.ID?

    /// The slot owns focus until the cue-out animation is visually complete.
    let focusedInterludeID: LyricInterlude.ID?

    /// The lyric promoted after the dots have disappeared, but before its
    /// authored start timestamp.
    let promotedLyricID: LyricLine.ID?

    let nextTransitionTime: TimeInterval?
}

enum LyricInterludeTimeline {
    /// The recovered animation needs one second before fill begins and the
    /// final 1.8 seconds for cue-out. Shorter gaps cannot express both stages.
    static let minimumAnimatedGapDuration: TimeInterval =
        AppleMusicInterludeMotionProfile.iOS26_6.fillLeadInDuration
        + AppleMusicInterludeMotionProfile.iOS26_6.cueOutLeadTime

    /// Build timing candidates once. Presentation policy can then be changed
    /// without reparsing lyrics or estimating vocal tails on every frame.
    static func candidates(in lyrics: [LyricLine]) -> [LyricInterlude] {
        guard let firstLyric = lyrics.first else { return [] }

        var result: [LyricInterlude] = []
        // NetEase YRC can prepend untimed credit rows at t=0. The first row
        // with usable content timing is the musical entrance; keep the
        // instrumental row immediately before that following lyric.
        let firstMusicalLyric = lyrics.first {
            contentEndTime(for: $0) != nil
        } ?? firstLyric
        if let prelude = makeInterlude(
            startTime: 0,
            precedingLyricID: nil,
            followingLyric: firstMusicalLyric,
            displayBeforeLyricID: firstMusicalLyric.id,
            timingSource: firstMusicalLyric.timingKind.interludeTimingSource
        ) {
            result.append(prelude)
        }

        guard lyrics.count > 1 else { return result }
        for followingIndex in lyrics.indices.dropFirst() {
            let precedingIndex = lyrics.index(before: followingIndex)
            let precedingLyric = lyrics[precedingIndex]
            let followingLyric = lyrics[followingIndex]
            guard let precedingEndTime = contentEndTime(
                for: precedingLyric
            ), let interlude = makeInterlude(
                startTime: precedingEndTime,
                precedingLyricID: precedingLyric.id,
                followingLyric: followingLyric,
                displayBeforeLyricID: followingLyric.id,
                timingSource: precedingLyric.timingKind.interludeTimingSource
            ) else {
                continue
            }
            result.append(interlude)
        }
        return result
    }

    static func interludes(
        in lyrics: [LyricLine],
        detectionPolicy: LyricInterludeDetectionPolicy
    ) -> [LyricInterlude] {
        interludes(
            from: candidates(in: lyrics),
            detectionPolicy: detectionPolicy
        )
    }

    static func interludes(
        from candidates: [LyricInterlude],
        detectionPolicy: LyricInterludeDetectionPolicy
    ) -> [LyricInterlude] {
        candidates.filter { interlude in
            switch (detectionPolicy, interlude.timingSource) {
            case (.preciseTiming, .precise):
                interlude.gapDuration >= minimumAnimatedGapDuration
            case (.preciseTiming, .lineSynchronized):
                false
            case (.automatic, .precise):
                interlude.gapDuration >= minimumAnimatedGapDuration
            case let (
                .automatic(minimumInferredGapDuration),
                .lineSynchronized
            ):
                interlude.gapDuration >= normalizedInferredThreshold(
                    minimumInferredGapDuration
                )
            }
        }
    }

    static func position(
        at playbackTime: TimeInterval,
        in interludes: [LyricInterlude]
    ) -> LyricInterludePlaybackPosition {
        guard playbackTime.isFinite else {
            return inactivePosition(nextTransitionTime: nil)
        }

        for interlude in interludes {
            let motionTiming =
                AppleMusicInterludeMotionProfile.iOS26_6.timing(
                    for: interlude
                )
            if playbackTime < interlude.startTime {
                return inactivePosition(
                    nextTransitionTime: interlude.startTime
                )
            }

            if playbackTime < motionTiming.visualEndTime {
                return LyricInterludePlaybackPosition(
                    visibleInterludeID: interlude.id,
                    focusedInterludeID: interlude.id,
                    promotedLyricID: nil,
                    nextTransitionTime: motionTiming.visualEndTime
                )
            }

            if playbackTime < interlude.countdownEndTime {
                return LyricInterludePlaybackPosition(
                    // Keep the resident slot identifiable until the authored
                    // lyric boundary so the view can recognize this as an
                    // interlude handoff. Its dot presentation is already
                    // visually empty after `visualEndTime`.
                    visibleInterludeID: interlude.id,
                    focusedInterludeID: nil,
                    promotedLyricID: interlude.followingLyricID,
                    nextTransitionTime: interlude.countdownEndTime
                )
            }
        }

        return inactivePosition(nextTransitionTime: nil)
    }

    private static func inactivePosition(
        nextTransitionTime: TimeInterval?
    ) -> LyricInterludePlaybackPosition {
        LyricInterludePlaybackPosition(
            visibleInterludeID: nil,
            focusedInterludeID: nil,
            promotedLyricID: nil,
            nextTransitionTime: nextTransitionTime
        )
    }

    private static func makeInterlude(
        startTime: TimeInterval,
        precedingLyricID: LyricLine.ID?,
        followingLyric: LyricLine,
        displayBeforeLyricID: LyricLine.ID,
        timingSource: LyricInterludeTimingSource
    ) -> LyricInterlude? {
        guard startTime.isFinite,
              followingLyric.time.isFinite else {
            return nil
        }

        let countdownEndTime = max(startTime, followingLyric.time)
        guard countdownEndTime > startTime else { return nil }

        return LyricInterlude(
            startTime: startTime,
            countdownEndTime: countdownEndTime,
            precedingLyricID: precedingLyricID,
            followingLyricID: followingLyric.id,
            displayBeforeLyricID: displayBeforeLyricID,
            timingSource: timingSource
        )
    }

    private static func contentEndTime(
        for lyric: LyricLine
    ) -> TimeInterval? {
        if lyric.timingKind == .lineSynchronized {
            let estimatedDuration =
                LyricVocalDurationEstimator.estimatedDuration(
                    for: lyric.text
                )
            let displayDuration = lyric.duration.flatMap {
                duration -> TimeInterval? in
                guard duration.isFinite, duration > 0 else { return nil }
                return duration
            }
            let contentDuration = min(
                estimatedDuration,
                displayDuration ?? estimatedDuration
            )
            return lyric.time + contentDuration
        }

        let durationEndTime: TimeInterval? = lyric.duration.flatMap {
            duration -> TimeInterval? in
            guard duration.isFinite, duration > 0 else { return nil }
            return lyric.time + duration
        }
        let syllableEndTime = lyric.syllables
            .lazy
            .map(\.endTime)
            .filter(\.isFinite)
            .max()

        return [durationEndTime, syllableEndTime]
            .compactMap { $0 }
            .max()
    }

    private static func normalizedInferredThreshold(
        _ value: TimeInterval
    ) -> TimeInterval {
        value.isFinite
            ? max(value, minimumAnimatedGapDuration)
            : minimumAnimatedGapDuration
    }
}

private extension LyricLineTimingKind {
    var interludeTimingSource: LyricInterludeTimingSource {
        switch self {
        case .precise:
            .precise
        case .lineSynchronized:
            .lineSynchronized
        }
    }
}
