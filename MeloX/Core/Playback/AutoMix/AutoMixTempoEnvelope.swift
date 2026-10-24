import Foundation

nonisolated enum AutoMixTempoEnvelope {
    static func playbackRate(
        at rawProgress: Double,
        startRate: Double,
        endRate: Double
    ) -> Float {
        let progress = smoothstep(rawProgress)
        return Float(
            max(
                startRate
                    + (endRate - startRate)
                        * progress,
                0.01
            )
        )
    }

    static func contentDuration(
        wallClockDuration: TimeInterval,
        startRate: Double,
        endRate: Double,
        through rawProgress: Double = 1
    ) -> TimeInterval {
        let duration = max(wallClockDuration, 0)
        let progress = clamped(rawProgress)
        let smoothstepIntegral =
            pow(progress, 3)
                - pow(progress, 4) / 2
        return duration
            * (
                max(startRate, 0.01) * progress
                    + (
                        max(endRate, 0.01)
                            - max(startRate, 0.01)
                    ) * smoothstepIntegral
            )
    }

    static func progress(
        forContentDuration contentDuration: TimeInterval,
        wallClockDuration: TimeInterval,
        startRate: Double,
        endRate: Double
    ) -> Double {
        let elapsedContent =
            max(contentDuration, 0)
        let totalContent = self.contentDuration(
            wallClockDuration:
                wallClockDuration,
            startRate: startRate,
            endRate: endRate
        )
        guard totalContent > 0 else { return 1 }
        guard elapsedContent < totalContent else {
            return 1
        }

        var lowerBound = 0.0
        var upperBound = 1.0
        for _ in 0..<18 {
            let midpoint =
                (lowerBound + upperBound) / 2
            let consumed = self.contentDuration(
                wallClockDuration:
                    wallClockDuration,
                startRate: startRate,
                endRate: endRate,
                through: midpoint
            )
            if consumed < elapsedContent {
                lowerBound = midpoint
            } else {
                upperBound = midpoint
            }
        }
        return (lowerBound + upperBound) / 2
    }

    private static func smoothstep(
        _ rawValue: Double
    ) -> Double {
        let value = clamped(rawValue)
        return value * value * (3 - 2 * value)
    }

    private static func clamped(
        _ value: Double
    ) -> Double {
        min(max(value, 0), 1)
    }
}
