import Foundation

nonisolated enum AutoMixTransitionOverlapScorer {
    static func penalty(
        outgoingStart: TimeInterval,
        incomingStart: TimeInterval,
        transitionDuration: TimeInterval,
        outgoingEndRate: Double,
        incomingStartRate: Double,
        outgoing: AutoMixTrackAnalysis,
        incoming: AutoMixTrackAnalysis
    ) -> Double {
        let sampleCount = 16
        var continuityPenalty = 0.0
        var lowFrequencyCrowding = 0.0
        var midFrequencyCrowding = 0.0
        var spectralMismatch = 0.0
        var loudnessMismatch = 0.0
        let outgoingReference = Double(
            AutoMixTransitionSignalMetrics
                .meanEnergy(
                    from: outgoingStart,
                    duration: 1,
                    analysis: outgoing
                )
        )
        let incomingEndTime =
            incomingStart
                + AutoMixTempoEnvelope
                    .contentDuration(
                        wallClockDuration:
                            transitionDuration,
                        startRate:
                            incomingStartRate,
                        endRate: 1
                    )
        let incomingReference = Double(
            AutoMixTransitionSignalMetrics
                .meanEnergy(
                    from:
                        max(
                            incomingEndTime - 1,
                            incomingStart
                        ),
                    duration: 1,
                    analysis: incoming
                )
        )

        for sampleIndex in 0...sampleCount {
            let progress =
                Double(sampleIndex)
                    / Double(sampleCount)
            let outgoingTime =
                outgoingStart
                    + AutoMixTempoEnvelope
                        .contentDuration(
                            wallClockDuration:
                                transitionDuration,
                            startRate: 1,
                            endRate:
                                outgoingEndRate,
                            through: progress
                        )
            let incomingTime =
                incomingStart
                    + AutoMixTempoEnvelope
                        .contentDuration(
                            wallClockDuration:
                                transitionDuration,
                            startRate:
                                incomingStartRate,
                            endRate: 1,
                            through: progress
                        )
            let gains = AutoMixFadeEnvelope.gains(
                at: progress,
                curve: .equalPower
            )
            let outgoingGain =
                Double(gains.outgoing)
            let incomingGain =
                Double(gains.incoming)
            let outgoingEnergy =
                Double(
                    outgoing.energy(
                        at: outgoingTime
                    )
                )
            let incomingEnergy =
                Double(
                    incoming.energy(
                        at: incomingTime
                    )
                )
            let combinedEnergy =
                outgoingEnergy * outgoingGain
                    + incomingEnergy
                        * incomingGain
            let expectedEnergy =
                outgoingReference
                    + (
                        incomingReference
                            - outgoingReference
                    ) * progress
            continuityPenalty += min(
                abs(
                    combinedEnergy
                        - expectedEnergy
                ),
                1
            )

            let outgoingProfile =
                outgoing.spectralProfile(
                    at: outgoingTime
                )
            let incomingProfile =
                incoming.spectralProfile(
                    at: incomingTime
                )
            let overlapGain =
                min(outgoingGain, incomingGain)
            lowFrequencyCrowding += min(
                Double(outgoingProfile.low)
                    * outgoingGain,
                Double(incomingProfile.low)
                    * incomingGain
            )
            let outgoingMidPresence =
                max(
                    Double(outgoingProfile.mid)
                        - 0.3,
                    0
                ) * outgoingEnergy
            let incomingMidPresence =
                max(
                    Double(incomingProfile.mid)
                        - 0.3,
                    0
                ) * incomingEnergy
            midFrequencyCrowding += min(
                outgoingMidPresence
                    * outgoingGain,
                incomingMidPresence
                    * incomingGain
            )
            spectralMismatch +=
                spectralDifference(
                    outgoingProfile,
                    incomingProfile
                ) * overlapGain
            loudnessMismatch +=
                loudnessDifference(
                    outgoing: outgoing,
                    outgoingTime: outgoingTime,
                    incoming: incoming,
                    incomingTime: incomingTime
                ) * overlapGain
        }

        let divisor =
            Double(sampleCount + 1)
        return min(
            continuityPenalty / divisor * 0.36
                + lowFrequencyCrowding
                    / divisor * 0.22
                + midFrequencyCrowding
                    / divisor * 0.17
                + spectralMismatch
                    / divisor * 0.1
                + loudnessMismatch
                    / divisor * 0.15,
            1
        )
    }

    private static func spectralDifference(
        _ outgoing: AutoMixSpectralProfile,
        _ incoming: AutoMixSpectralProfile
    ) -> Double {
        abs(
            Double(outgoing.low)
                - Double(incoming.low)
        )
            + abs(
                Double(outgoing.mid)
                    - Double(incoming.mid)
            )
            + abs(
                Double(outgoing.high)
                    - Double(incoming.high)
            )
    }

    private static func loudnessDifference(
        outgoing: AutoMixTrackAnalysis,
        outgoingTime: TimeInterval,
        incoming: AutoMixTrackAnalysis,
        incomingTime: TimeInterval
    ) -> Double {
        let outgoingLoudness =
            Double(
                outgoing.loudness(
                    at: outgoingTime
                )
            )
        let incomingLoudness =
            Double(
                incoming.loudness(
                    at: incomingTime
                )
            )
        guard outgoingLoudness.isFinite,
              incomingLoudness.isFinite else {
            return 0
        }
        return min(
            abs(
                outgoingLoudness
                    - incomingLoudness
            ) / 18,
            1
        )
    }
}
