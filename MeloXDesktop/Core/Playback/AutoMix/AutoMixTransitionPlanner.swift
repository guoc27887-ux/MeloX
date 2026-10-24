import Foundation

enum AutoMixTransitionKind: String, Sendable {
    case smart
    case fixed
    case fallback
}

struct AutoMixTransitionPlan: Equatable, Sendable {
    let kind: AutoMixTransitionKind
    let outgoingStartTime: TimeInterval
    let duration: TimeInterval
    let incomingStartTime: TimeInterval
    let outgoingEndPlaybackRate: Double
    let incomingStartPlaybackRate: Double
    let fadeCurve: AutoMixFadeCurve
    let confidence: Double?
}

enum AutoMixTransitionPlanner {
    private struct TempoRates {
        let alignedIncomingBPM: Double
        let outgoingEnd: Double
        let incomingStart: Double
    }

    static func makePlan(
        configuration: AutoMixConfiguration,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        analysis: AutoMixPairAnalysis?
    ) -> AutoMixTransitionPlan? {
        let outgoingDuration =
            max(outgoingDuration, 0)
        let incomingDuration =
            max(incomingDuration, 0)
        guard outgoingDuration > 1,
              incomingDuration > 1 else {
            return nil
        }

        if configuration.mode == .fixed {
            return fixedPlan(
                kind: .fixed,
                duration:
                    configuration.fixedDuration,
                outgoingDuration:
                    outgoingDuration,
                incomingDuration:
                    incomingDuration,
                fadeCurve:
                    configuration.fadeCurve
            )
        }

        if let analysis,
           let smartPlan = smartPlan(
               configuration: configuration,
               outgoingDuration:
                   outgoingDuration,
               incomingDuration:
                   incomingDuration,
               analysis: analysis
           ) {
            return smartPlan
        }

        switch configuration.fallbackBehavior {
        case .crossfade:
            return fixedPlan(
                kind: .fallback,
                duration:
                    configuration.fixedDuration,
                outgoingDuration:
                    outgoingDuration,
                incomingDuration:
                    incomingDuration,
                fadeCurve:
                    configuration.fadeCurve,
                outgoingEndOffset:
                    estimatedTailCutDuration(
                        bars:
                            configuration.tailCutBars
                    )
            )
        case .shortCrossfade:
            return fixedPlan(
                kind: .fallback,
                duration: 3,
                outgoingDuration:
                    outgoingDuration,
                incomingDuration:
                    incomingDuration,
                fadeCurve:
                    configuration.fadeCurve,
                outgoingEndOffset:
                    estimatedTailCutDuration(
                        bars:
                            configuration.tailCutBars
                    )
            )
        case .normal:
            return nil
        }
    }

    private static func smartPlan(
        configuration: AutoMixConfiguration,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        analysis: AutoMixPairAnalysis
    ) -> AutoMixTransitionPlan? {
        let confidence = min(
            analysis.outgoing.confidence,
            analysis.incoming.confidence
        )
        guard confidence
                >= configuration
                    .minimumAnalysisConfidence,
              analysis.outgoing.bpm.isFinite,
              analysis.incoming.bpm.isFinite,
              analysis.outgoing.bpm > 0,
              analysis.incoming.bpm > 0,
              !analysis.outgoing.beats.isEmpty,
              !analysis.incoming.beats.isEmpty else {
            return nil
        }

        let tempoRates = tempoRates(
            outgoingBPM:
                analysis.outgoing.bpm,
            incomingBPM:
                analysis.incoming.bpm,
            configuration: configuration
        )
        let outgoingSecondsPerBeat =
            60 / analysis.outgoing.bpm
        let incomingSecondsPerBeat =
            60
                / tempoRates
                    .alignedIncomingBPM
        let secondsPerBar =
            outgoingSecondsPerBeat * 4
        let desiredOutgoingEnd = min(
            max(
                outgoingDuration
                    - Double(
                        configuration.tailCutBars
                    ) * secondsPerBar,
                1
            ),
            outgoingDuration
        )
        let requestedDuration =
            Double(
                configuration.transitionBars * 4
            )
                * (
                    outgoingSecondsPerBeat
                        + incomingSecondsPerBeat
                ) / 2
        let averageOutgoingRate =
            (
                1
                    + tempoRates.outgoingEnd
            ) / 2
        let averageIncomingRate =
            (
                tempoRates.incomingStart
                    + 1
            ) / 2
        let maximumDuration = min(
            max(
                (desiredOutgoingEnd - 0.5)
                    / max(
                        averageOutgoingRate,
                        0.01
                    ),
                0
            ),
            max(
                (incomingDuration - 0.5)
                    / max(
                        averageIncomingRate,
                        0.01
                    ),
                0
            ),
            32
        )
        let transitionDuration = min(
            max(requestedDuration, 3),
            maximumDuration
        )
        guard transitionDuration >= 1 else {
            return nil
        }

        guard let candidate =
                AutoMixTransitionScorer
                    .bestCandidate(
                        outgoing:
                            analysis.outgoing,
                        incoming:
                            analysis.incoming,
                        outgoingDuration:
                            outgoingDuration,
                        incomingDuration:
                            incomingDuration,
                        desiredOutgoingEnd:
                            desiredOutgoingEnd,
                        transitionDuration:
                            transitionDuration,
                        outgoingEndRate:
                            tempoRates.outgoingEnd,
                        incomingStartRate:
                            tempoRates.incomingStart,
                        skipsQuietOpening:
                            configuration
                                .skipsQuietOpening
                    ) else {
            return nil
        }

        return AutoMixTransitionPlan(
            kind: .smart,
            outgoingStartTime:
                candidate.outgoingStartTime,
            duration: transitionDuration,
            incomingStartTime:
                candidate.incomingStartTime,
            outgoingEndPlaybackRate:
                tempoRates.outgoingEnd,
            incomingStartPlaybackRate:
                tempoRates.incomingStart,
            fadeCurve:
                configuration.fadeCurve,
            confidence: confidence
        )
    }

    private static func tempoRates(
        outgoingBPM: Double,
        incomingBPM: Double,
        configuration: AutoMixConfiguration
    ) -> TempoRates {
        let alignedIncomingBPM = [
            incomingBPM / 2,
            incomingBPM,
            incomingBPM * 2,
        ].min {
            abs($0 - outgoingBPM)
                < abs($1 - outgoingBPM)
        } ?? incomingBPM
        guard configuration.tempoMatchingEnabled else {
            return TempoRates(
                alignedIncomingBPM:
                    alignedIncomingBPM,
                outgoingEnd: 1,
                incomingStart: 1
            )
        }

        let incomingStartRate =
            outgoingBPM / alignedIncomingBPM
        let adjustmentPercent =
            abs(incomingStartRate - 1) * 100
        guard adjustmentPercent
                <= configuration
                    .maximumTempoAdjustmentPercent else {
            return TempoRates(
                alignedIncomingBPM:
                    alignedIncomingBPM,
                outgoingEnd: 1,
                incomingStart: 1
            )
        }

        return TempoRates(
            alignedIncomingBPM:
                alignedIncomingBPM,
            outgoingEnd:
                min(
                    max(
                        alignedIncomingBPM
                            / outgoingBPM,
                        0.92
                    ),
                    1.08
                ),
            incomingStart:
                min(
                    max(
                        incomingStartRate,
                        0.92
                    ),
                    1.08
                )
        )
    }

    private static func fixedPlan(
        kind: AutoMixTransitionKind,
        duration requestedDuration:
            TimeInterval,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        fadeCurve: AutoMixFadeCurve,
        outgoingEndOffset:
            TimeInterval = 0
    ) -> AutoMixTransitionPlan? {
        let outgoingEndTime = min(
            max(
                outgoingDuration
                    - max(
                        outgoingEndOffset,
                        0
                    ),
                1
            ),
            outgoingDuration
        )
        let duration = min(
            max(requestedDuration, 1),
            outgoingEndTime,
            max(incomingDuration - 1, 1)
        )
        guard duration >= 1 else {
            return nil
        }
        return AutoMixTransitionPlan(
            kind: kind,
            outgoingStartTime:
                max(
                    outgoingEndTime - duration,
                    0
                ),
            duration: duration,
            incomingStartTime: 0,
            outgoingEndPlaybackRate: 1,
            incomingStartPlaybackRate: 1,
            fadeCurve: fadeCurve,
            confidence: nil
        )
    }

    private static func estimatedTailCutDuration(
        bars: Int
    ) -> TimeInterval {
        Double(max(bars, 0))
            * 4
            * 0.5
    }
}
