import Foundation

nonisolated struct PlaybackBeatTimeline:
    Equatable,
    Sendable
{
    private static let framesPerSecond = 50.0
    private static let modelFrameCount =
        BeatNetFeatureExtractor.frameCount
    static let modelVignetteTriggerThreshold =
        0.40
    static let onsetVignetteTriggerThreshold =
        0.40
    static let downbeatVignetteAccentThreshold =
        0.60
    static let vignetteModelTolerance =
        0.020
    static let vignetteMinimumRetriggerInterval =
        0.220
    static let debugModelPeakHoldDuration =
        0.16
    private static let vignetteAttackDuration =
        0.055
    private static let regularVignetteStrength:
        Float = 0.88
    private static let accentedVignetteStrength:
        Float = 1

    let bpm: Double
    let confidence: Double

    private let beats: [TimeInterval]
    private let downbeatPhase: Int
    private let regionStart: TimeInterval
    private let beatActivations: [Float]
    private let downbeatActivations: [Float]
    private let onsetActivations: [Float]
    private let vignetteTriggerActivations:
        [Float]
    private let downbeatCount: Int
    private let featureStatistics:
        BeatNetFeatureStatistics
    private let finalAllZeroSegmentCount: Int
    private let analyzedSegmentCount: Int
    private let maximumBeatActivation: Double
    private let maximumDownbeatActivation: Double
    private let nonzeroBeatFrameCount: Int
    private let nonzeroDownbeatFrameCount: Int

    init?(analysis: AutoMixTrackAnalysis) {
        let sortedBeats = analysis.beats.sorted()
        guard analysis.bpm.isFinite,
              analysis.bpm > 0,
              !analysis.normalizedEnergy.isEmpty else {
            return nil
        }

        bpm = analysis.bpm
        confidence = min(
            max(analysis.confidence, 0),
            1
        )
        beats = sortedBeats
        downbeatCount = analysis.downbeats.count
        downbeatPhase = Self.downbeatPhase(
            beats: sortedBeats,
            downbeats: analysis.downbeats
        )
        regionStart = analysis.regionStart
        let beatActivations =
            analysis.modelBeatActivations
        self.beatActivations =
            beatActivations
        let downbeatActivations =
            analysis.modelDownbeatActivations
        self.downbeatActivations =
            downbeatActivations
        featureStatistics =
            analysis.featureStatistics
        finalAllZeroSegmentCount =
            analysis.finalAllZeroSegmentCount
        analyzedSegmentCount =
            analysis.analyzedSegmentCount
        maximumBeatActivation =
            Double(beatActivations.max() ?? 0)
        maximumDownbeatActivation =
            Double(
                downbeatActivations.max() ?? 0
            )
        nonzeroBeatFrameCount =
            beatActivations
                .lazy
                .filter { $0 > 0 }
                .count
        nonzeroDownbeatFrameCount =
            downbeatActivations
                .lazy
                .filter { $0 > 0 }
                .count
        let onsetActivations =
            Self.onsetActivations(
                from: analysis.normalizedEnergy
            )
        self.onsetActivations =
            onsetActivations
        vignetteTriggerActivations =
            PlaybackVignetteTriggerDecoder
                .activations(
                beats: beatActivations,
                downbeats:
                    downbeatActivations,
                onsets: onsetActivations,
                configuration:
                    .init(
                        framesPerSecond:
                            Self.framesPerSecond,
                        modelThreshold:
                            Self
                                .modelVignetteTriggerThreshold,
                        onsetThreshold:
                            Self
                                .onsetVignetteTriggerThreshold,
                        modelTolerance:
                            Self
                                .vignetteModelTolerance,
                        minimumRetriggerInterval:
                            Self
                                .vignetteMinimumRetriggerInterval,
                        downbeatAccentThreshold:
                            Self
                                .downbeatVignetteAccentThreshold,
                        regularStrength:
                            Self
                                .regularVignetteStrength,
                        accentedStrength:
                            Self
                                .accentedVignetteStrength
                    )
                )
    }

    func vignettePulse(
        at playbackTime: TimeInterval
    ) -> Double {
        guard playbackTime.isFinite else {
            return 0
        }
        return vignetteActivationPulse(
            triggers:
                vignetteTriggerActivations,
            at: playbackTime,
            duration: 0.32,
            exponent: 1.55
        )
    }

    func debugSnapshot(
        at playbackTime: TimeInterval
    ) -> PlaybackBeatDebugSnapshot {
        let relativeTime =
            playbackTime - regionStart
        let requestedFrameIndex = Int(
            floor(
                relativeTime
                    * Self.framesPerSecond
            )
        )
        let regionEnd =
            regionStart
                + Double(beatActivations.count)
                    / Self.framesPerSecond
        let isInsideAnalysisRegion =
            !beatActivations.isEmpty
                && playbackTime >= regionStart
                && playbackTime <= regionEnd
        let frameIndex =
            isInsideAnalysisRegion
            ? min(
                max(requestedFrameIndex, 0),
                beatActivations.count - 1
            )
            : requestedFrameIndex
        let event = beatEvent(
            at: playbackTime
        )
        let beatInBar = event.map {
            Self.positiveModulo(
                $0.ordinal - downbeatPhase,
                divisor: 4
            ) + 1
        }
        let currentBeatActivation =
            activation(
                in: beatActivations,
                frameIndex: frameIndex
            )
        let currentDownbeatActivation =
            activation(
                in: downbeatActivations,
                frameIndex: frameIndex
            )
        let currentOnsetActivation =
            activation(
                in: onsetActivations,
                frameIndex: frameIndex
            )
        let recentVignetteTriggerActivation =
            recentPeakActivation(
                in:
                    vignetteTriggerActivations,
                frameIndex: frameIndex
            )
        let jointVignetteGateIsActive =
            recentVignetteTriggerActivation > 0
        let appliedVignettePulse =
            vignettePulse(
                at: playbackTime
            )

        return PlaybackBeatDebugSnapshot(
            playbackTime: playbackTime,
            regionStart: regionStart,
            regionEnd: regionEnd,
            frameIndex:
                isInsideAnalysisRegion
                    ? frameIndex
                    : nil,
            frameCount: beatActivations.count,
            isInsideAnalysisRegion:
                isInsideAnalysisRegion,
            bpm: bpm,
            confidence: confidence,
            decodedBeatCount: beats.count,
            decodedDownbeatCount: downbeatCount,
            beatOrdinal:
                event.map { $0.ordinal + 1 },
            beatInBar: beatInBar,
            secondsSinceBeat:
                event.map {
                    max(
                        playbackTime - $0.time,
                        0
                    )
                },
            recentBeatActivation:
                recentPeakActivation(
                    in: beatActivations,
                    frameIndex: frameIndex
                ),
            recentDownbeatActivation:
                recentPeakActivation(
                    in: downbeatActivations,
                    frameIndex: frameIndex
                ),
            currentBeatActivation:
                currentBeatActivation,
            currentDownbeatActivation:
                currentDownbeatActivation,
            normalizedOnsetActivation:
                currentOnsetActivation,
            recentVignetteTriggerActivation:
                recentVignetteTriggerActivation,
            maximumBeatActivation:
                maximumBeatActivation,
            maximumDownbeatActivation:
                maximumDownbeatActivation,
            nonzeroBeatFrameCount:
                nonzeroBeatFrameCount,
            nonzeroDownbeatFrameCount:
                nonzeroDownbeatFrameCount,
            featureStatistics:
                featureStatistics,
            finalAllZeroSegmentCount:
                finalAllZeroSegmentCount,
            analyzedSegmentCount:
                analyzedSegmentCount,
            jointVignetteGateIsActive:
                jointVignetteGateIsActive,
            appliedVignettePulse:
                appliedVignettePulse,
            vignettePulse:
                appliedVignettePulse
        )
    }

    private func activation(
        in values: [Float],
        frameIndex: Int
    ) -> Double {
        guard values.indices.contains(
            frameIndex
        ) else {
            return 0
        }
        return min(
            max(
                Double(values[frameIndex]),
                0
            ),
            1
        )
    }

    private func recentPeakActivation(
        in values: [Float],
        frameIndex: Int
    ) -> Double {
        guard values.indices.contains(
            frameIndex
        ) else {
            return 0
        }
        let lookbackFrameCount = max(
            Int(
                ceil(
                    Self
                        .debugModelPeakHoldDuration
                        * Self.framesPerSecond
                )
            ),
            1
        )
        let lowerBound = max(
            frameIndex
                - lookbackFrameCount
                + 1,
            values.startIndex
        )
        let peak =
            values[lowerBound...frameIndex]
                .max()
                ?? 0
        return min(
            max(Double(peak), 0),
            1
        )
    }

    private func vignetteActivationPulse(
        triggers: [Float],
        at playbackTime: TimeInterval,
        duration: TimeInterval,
        exponent: Double
    ) -> Double {
        let relativeTime =
            playbackTime - regionStart
        guard relativeTime >= 0,
              duration > 0,
              !triggers.isEmpty else {
            return 0
        }

        let exactFrame =
            relativeTime
                * Self.framesPerSecond
        let currentFrame = Int(
            floor(exactFrame)
        )
        let subframeAge =
            (
                exactFrame
                    - Double(currentFrame)
            ) / Self.framesPerSecond
        let lookbackFrames = max(
            Int(
                ceil(
                    duration
                        * Self.framesPerSecond
                )
            ),
            1
        )
        var strongest = 0.0
        for offset in 0...lookbackFrames {
            let frame = currentFrame - offset
            guard triggers.indices.contains(
                frame
            ) else {
                continue
            }
            let age =
                subframeAge
                    + Double(offset)
                        / Self.framesPerSecond
            guard age <= duration else {
                continue
            }
            let envelope: Double
            if age
                < Self.vignetteAttackDuration {
                let progress = min(
                    max(
                        age
                            / Self
                                .vignetteAttackDuration,
                        0
                    ),
                    1
                )
                envelope =
                    progress
                        * progress
                        * (3 - 2 * progress)
            } else {
                let decayDuration = max(
                    duration
                        - Self
                            .vignetteAttackDuration,
                    0.01
                )
                let decayProgress =
                    (
                        age
                            - Self
                                .vignetteAttackDuration
                    ) / decayDuration
                envelope = pow(
                    max(1 - decayProgress, 0),
                    exponent
                )
            }
            let response = min(
                max(
                    Double(triggers[frame]),
                    0
                ),
                1
            )
            strongest = max(
                strongest,
                response * envelope
            )
        }
        return min(strongest, 1)
    }

    private static func onsetActivations(
        from energy: [Float]
    ) -> [Float] {
        guard energy.count >= 2 else {
            return Array(
                repeating: 0,
                count: energy.count
            )
        }

        var rawOnsets = Array(
            repeating: Float.zero,
            count: energy.count
        )
        for index in 1..<energy.count {
            let segmentStart =
                (index / Self.modelFrameCount)
                    * Self.modelFrameCount
            guard index > segmentStart else {
                continue
            }
            let lowerBound = max(
                index - 10,
                segmentStart
            )
            let baselineSlice =
                energy[lowerBound..<index]
            let baseline =
                baselineSlice.reduce(0, +)
                    / Float(
                        max(
                            baselineSlice.count,
                            1
                        )
                    )
            let current = energy[index]
            let previous = energy[index - 1]
            let slope = max(
                current - previous,
                0
            )
            let contrast = max(
                current - baseline,
                0
            )
            rawOnsets[index] = sqrt(
                slope * contrast
            )
        }

        guard let maximum = rawOnsets.max(),
              maximum > 0 else {
            return rawOnsets
        }
        let sortedOnsets = rawOnsets.sorted()
        let peakIndex = min(
            Int(
                Double(sortedOnsets.count - 1)
                    * 0.985
            ),
            sortedOnsets.count - 1
        )
        let scale = max(
            sortedOnsets[peakIndex],
            maximum * 0.12,
            Float.leastNonzeroMagnitude
        )

        return rawOnsets.map { value in
            let linear = min(
                max(value / scale, 0),
                1
            )
            return linear * linear * (3 - 2 * linear)
        }
    }

    private var secondsPerBeat: TimeInterval {
        60 / bpm
    }

    private func beatEvent(
        at playbackTime: TimeInterval
    ) -> (time: TimeInterval, ordinal: Int)? {
        guard let firstBeat = beats.first,
              playbackTime >= firstBeat else {
            return nil
        }

        if let lastBeat = beats.last,
           playbackTime > lastBeat {
            let additionalBeats = Int(
                floor(
                    (playbackTime - lastBeat)
                        / secondsPerBeat
                )
            )
            return (
                lastBeat
                    + Double(additionalBeats)
                        * secondsPerBeat,
                beats.count - 1 + additionalBeats
            )
        }

        var lowerBound = 0
        var upperBound = beats.count
        while lowerBound < upperBound {
            let middle =
                (lowerBound + upperBound) / 2
            if beats[middle] <= playbackTime {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }
        let index = max(lowerBound - 1, 0)
        return (beats[index], index)
    }

    private static func downbeatPhase(
        beats: [TimeInterval],
        downbeats: [TimeInterval]
    ) -> Int {
        guard let firstDownbeat = downbeats.first,
              let closestIndex = beats.indices.min(
                  by: {
                      abs(beats[$0] - firstDownbeat)
                          < abs(
                              beats[$1]
                                  - firstDownbeat
                          )
                  }
              ) else {
            return 0
        }
        return closestIndex % 4
    }

    private static func positiveModulo(
        _ value: Int,
        divisor: Int
    ) -> Int {
        let remainder = value % divisor
        return remainder >= 0
            ? remainder
            : remainder + divisor
    }
}
