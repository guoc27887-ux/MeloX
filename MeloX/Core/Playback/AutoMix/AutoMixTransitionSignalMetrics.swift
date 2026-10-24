import Foundation

nonisolated struct AutoMixBeatCandidate:
    Sendable
{
    let time: TimeInterval
    let index: Int
}

nonisolated enum AutoMixTransitionSignalMetrics {
    static func boundaryStrength(
        at time: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Double {
        let offsets = stride(
            from: -0.8,
            through: 0.8,
            by: 0.1
        )
        let novelty = offsets.map {
            Double(
                analysis.novelty(
                    at: max(time + $0, 0)
                )
            )
        }.max() ?? 0
        let before = Double(
            meanEnergy(
                from: max(time - 1.5, 0),
                duration: 1.5,
                analysis: analysis
            )
        )
        let after = Double(
            meanEnergy(
                from: time,
                duration: 1.5,
                analysis: analysis
            )
        )
        return min(
            novelty * 0.75
                + abs(after - before) * 0.25,
            1
        )
    }

    static func outgoingContourPenalty(
        at time: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Double {
        let before = Double(
            meanEnergy(
                from: max(time - 2, 0),
                duration: 2,
                analysis: analysis
            )
        )
        let after = Double(
            meanEnergy(
                from: time,
                duration: 2,
                analysis: analysis
            )
        )
        return min(max(after - before, 0), 1)
    }

    static func incomingContourPenalty(
        at time: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Double {
        let opening = Double(
            meanEnergy(
                from: time,
                duration: 1.5,
                analysis: analysis
            )
        )
        let following = Double(
            meanEnergy(
                from: time + 2,
                duration: 1.5,
                analysis: analysis
            )
        )
        return min(max(opening - following, 0), 1)
    }

    static func phrasePenalty(
        beatIndex: Int
    ) -> Double {
        let remainder = beatIndex % 16
        return Double(
            min(remainder, 16 - remainder)
        ) / 8
    }

    static func meanEnergy(
        from startTime: TimeInterval,
        duration: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Float {
        let sampleCount = max(
            Int((duration / 0.1).rounded()),
            1
        )
        let values = (0...sampleCount).map {
            analysis.energy(
                at:
                    startTime
                        + Double($0)
                            * duration
                            / Double(sampleCount)
            )
        }
        return values.reduce(0, +)
            / Float(max(values.count, 1))
    }

    static func beatCandidates(
        in analysis: AutoMixTrackAnalysis
    ) -> [AutoMixBeatCandidate] {
        let sorted = (
            analysis.beats
                + analysis.downbeats
        ).filter(\.isFinite).sorted()
        let boundaries = sorted.reduce(
            into: [TimeInterval]()
        ) { result, time in
            guard let previous = result.last,
                  abs(time - previous) < 0.08 else {
                result.append(time)
                return
            }
        }
        return boundaries.enumerated().map {
            AutoMixBeatCandidate(
                time: $0.element,
                index: $0.offset
            )
        }
    }
}
