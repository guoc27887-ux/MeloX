import Foundation

nonisolated enum PlaybackVignetteTriggerDecoder {
    struct Configuration: Sendable {
        let framesPerSecond: Double
        let modelThreshold: Double
        let onsetThreshold: Double
        let modelTolerance: TimeInterval
        let minimumRetriggerInterval:
            TimeInterval
        let downbeatAccentThreshold: Double
        let regularStrength: Float
        let accentedStrength: Float
    }

    private struct Candidate {
        let frame: Int
        let score: Float
        let strength: Float
    }

    static func activations(
        beats: [Float],
        downbeats: [Float],
        onsets: [Float],
        configuration: Configuration
    ) -> [Float] {
        var triggers = Array(
            repeating: Float.zero,
            count: onsets.count
        )
        let frameCount = min(
            onsets.count,
            min(
                beats.count,
                downbeats.count
            )
        )
        guard frameCount >= 3,
              configuration.framesPerSecond
                > 0 else {
            return triggers
        }

        let toleranceFrames = max(
            Int(
                (
                    configuration
                        .modelTolerance
                        * configuration
                            .framesPerSecond
                ).rounded()
            ),
            0
        )
        let minimumRetriggerFrames = max(
            Int(
                ceil(
                    configuration
                        .minimumRetriggerInterval
                        * configuration
                            .framesPerSecond
                )
            ),
            1
        )
        let modelThreshold = Float(
            configuration.modelThreshold
        )
        let onsetThreshold = Float(
            configuration.onsetThreshold
        )
        let downbeatAccentThreshold =
            Float(
                configuration
                    .downbeatAccentThreshold
            )
        var selected: [Candidate] = []

        for frame in 1..<(frameCount - 1) {
            let onset = onsets[frame]
            let previousOnset =
                onsets[frame - 1]
            let nextOnset =
                onsets[frame + 1]
            guard onset.isFinite,
                  previousOnset.isFinite,
                  nextOnset.isFinite,
                  onset >= onsetThreshold,
                  onset >= previousOnset,
                  onset >= nextOnset,
                  onset > previousOnset
                    || onset > nextOnset else {
                continue
            }

            let lowerBound = max(
                frame - toleranceFrames,
                0
            )
            let upperBound = min(
                frame + toleranceFrames,
                frameCount - 1
            )
            var modelConfirmation:
                Float = 0
            var downbeatConfirmation:
                Float = 0
            for modelFrame in
                lowerBound...upperBound {
                let beat = beats[modelFrame]
                let downbeat =
                    downbeats[modelFrame]
                if beat.isFinite {
                    modelConfirmation = max(
                        modelConfirmation,
                        beat
                    )
                }
                if downbeat.isFinite {
                    downbeatConfirmation = max(
                        downbeatConfirmation,
                        downbeat
                    )
                    modelConfirmation = max(
                        modelConfirmation,
                        downbeat
                    )
                }
            }
            guard modelConfirmation
                >= modelThreshold else {
                continue
            }

            let candidate = Candidate(
                frame: frame,
                score:
                    onset
                        * modelConfirmation,
                strength:
                    downbeatConfirmation
                        >= downbeatAccentThreshold
                    ? configuration
                        .accentedStrength
                    : configuration
                        .regularStrength
            )
            if let last = selected.last,
               candidate.frame - last.frame
                < minimumRetriggerFrames {
                if candidate.score > last.score {
                    selected[
                        selected.count - 1
                    ] = candidate
                }
            } else {
                selected.append(candidate)
            }
        }

        for candidate in selected {
            triggers[candidate.frame] =
                candidate.strength
        }
        return triggers
    }
}
