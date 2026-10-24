import Foundation

nonisolated struct AutoMixTransitionCandidate:
    Sendable
{
    let outgoingStartTime: TimeInterval
    let incomingStartTime: TimeInterval
    let score: Double
}

nonisolated enum AutoMixTransitionScorer {
    static func bestCandidate(
        outgoing: AutoMixTrackAnalysis,
        incoming: AutoMixTrackAnalysis,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        desiredOutgoingEnd: TimeInterval,
        transitionDuration: TimeInterval,
        outgoingEndRate: Double,
        incomingStartRate: Double,
        skipsQuietOpening: Bool
    ) -> AutoMixTransitionCandidate? {
        let outgoingContentDuration =
            AutoMixTempoEnvelope.contentDuration(
                wallClockDuration:
                    transitionDuration,
                startRate: 1,
                endRate: outgoingEndRate
            )
        let incomingContentDuration =
            AutoMixTempoEnvelope.contentDuration(
                wallClockDuration:
                    transitionDuration,
                startRate: incomingStartRate,
                endRate: 1
            )
        let latestOutgoingStart =
            desiredOutgoingEnd
                - outgoingContentDuration
        let latestIncomingStart =
            min(
                incomingDuration * 0.25,
                48,
                incomingDuration
                    - incomingContentDuration
                    - 0.25
            )
        guard latestOutgoingStart > 0,
              latestIncomingStart >= 0 else {
            return nil
        }

        let outgoingBeats =
            AutoMixTransitionSignalMetrics
                .beatCandidates(in: outgoing)
        let incomingBeats =
            AutoMixTransitionSignalMetrics
                .beatCandidates(in: incoming)
        guard !outgoingBeats.isEmpty,
              !incomingBeats.isEmpty else {
            return nil
        }

        let targetOutgoingStart =
            latestOutgoingStart
        let earliestOutgoingStart = max(
            outgoingDuration * 0.52,
            targetOutgoingStart
                - max(transitionDuration * 2, 24),
            outgoing.regionStart
        )
        var outgoingCandidates =
            outgoingBeats.filter {
                $0.time >= earliestOutgoingStart
                    && $0.time
                        <= latestOutgoingStart + 0.08
            }
        if outgoingCandidates.isEmpty {
            outgoingCandidates =
                outgoingBeats.filter {
                    $0.time
                        <= latestOutgoingStart + 0.08
                }.suffix(48)
        }

        var incomingCandidates =
            incomingBeats.filter {
                $0.time >= 0
                    && $0.time
                        <= latestIncomingStart + 0.08
            }
        if incomingCandidates.isEmpty,
           latestIncomingStart >= 0 {
            incomingCandidates = [
                AutoMixBeatCandidate(
                    time: 0,
                    index: 0
                )
            ]
        }
        guard !outgoingCandidates.isEmpty,
              !incomingCandidates.isEmpty else {
            return nil
        }

        var bestCandidate:
            AutoMixTransitionCandidate?
        for outgoingCandidate in outgoingCandidates {
            for incomingCandidate in incomingCandidates {
                let score = score(
                    outgoingCandidate:
                        outgoingCandidate,
                    incomingCandidate:
                        incomingCandidate,
                    targetOutgoingStart:
                        targetOutgoingStart,
                    transitionDuration:
                        transitionDuration,
                    outgoingEndRate:
                        outgoingEndRate,
                    incomingStartRate:
                        incomingStartRate,
                    outgoing: outgoing,
                    incoming: incoming,
                    skipsQuietOpening:
                        skipsQuietOpening
                )
                if let bestCandidate,
                   score >= bestCandidate.score {
                    continue
                }
                bestCandidate =
                    AutoMixTransitionCandidate(
                        outgoingStartTime:
                            outgoingCandidate.time,
                        incomingStartTime:
                            incomingCandidate.time,
                        score: score
                    )
            }
        }
        return bestCandidate
    }

    private static func score(
        outgoingCandidate: AutoMixBeatCandidate,
        incomingCandidate: AutoMixBeatCandidate,
        targetOutgoingStart: TimeInterval,
        transitionDuration: TimeInterval,
        outgoingEndRate: Double,
        incomingStartRate: Double,
        outgoing: AutoMixTrackAnalysis,
        incoming: AutoMixTrackAnalysis,
        skipsQuietOpening: Bool
    ) -> Double {
        let timingPenalty = min(
            abs(
                outgoingCandidate.time
                    - targetOutgoingStart
            ) / max(transitionDuration * 1.75, 12),
            1
        )
        let phrasePenalty =
            (
                AutoMixTransitionSignalMetrics
                    .phrasePenalty(
                        beatIndex:
                            outgoingCandidate.index
                    )
                    + AutoMixTransitionSignalMetrics
                        .phrasePenalty(
                            beatIndex:
                                incomingCandidate.index
                        )
            ) / 2
        let boundaryPenalty =
            1
                - (
                    AutoMixTransitionSignalMetrics
                        .boundaryStrength(
                            at:
                                outgoingCandidate.time,
                            analysis: outgoing
                        )
                        + AutoMixTransitionSignalMetrics
                            .boundaryStrength(
                                at:
                                    incomingCandidate
                                        .time,
                                analysis: incoming
                            )
                ) / 2
        let contourPenalty =
            (
                AutoMixTransitionSignalMetrics
                    .outgoingContourPenalty(
                        at: outgoingCandidate.time,
                        analysis: outgoing
                    )
                    + AutoMixTransitionSignalMetrics
                        .incomingContourPenalty(
                            at: incomingCandidate.time,
                            analysis: incoming
                        )
            ) / 2
        let quietIncomingPenalty: Double
        if skipsQuietOpening {
            quietIncomingPenalty = max(
                0.2
                    - Double(
                        AutoMixTransitionSignalMetrics
                            .meanEnergy(
                                from:
                                    incomingCandidate
                                        .time,
                                duration: 1.5,
                                analysis: incoming
                            )
                    ),
                0
            ) / 0.2
        } else {
            quietIncomingPenalty = 0
        }
        let quietOutgoingPenalty = max(
            0.12
                - Double(
                    AutoMixTransitionSignalMetrics
                        .meanEnergy(
                            from:
                                outgoingCandidate.time,
                            duration: 1.5,
                            analysis: outgoing
                        )
                ),
            0
        ) / 0.12
        let overlapPenalty =
            AutoMixTransitionOverlapScorer
                .penalty(
                    outgoingStart:
                        outgoingCandidate.time,
                    incomingStart:
                        incomingCandidate.time,
                    transitionDuration:
                        transitionDuration,
                    outgoingEndRate:
                        outgoingEndRate,
                    incomingStartRate:
                        incomingStartRate,
                    outgoing: outgoing,
                    incoming: incoming
                )
        let tempoPenalty = min(
            abs(incomingStartRate - 1)
                / 0.08,
            1
        )

        return timingPenalty * 0.25
            + phrasePenalty * 0.08
            + boundaryPenalty * 0.19
            + contourPenalty * 0.13
            + quietIncomingPenalty * 0.09
            + quietOutgoingPenalty * 0.05
            + overlapPenalty * 0.17
            + tempoPenalty * 0.04
    }
}
