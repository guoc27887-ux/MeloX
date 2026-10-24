import Foundation

/// Pure reconstruction of the duration-dependent spring calculation observed
/// in LyricsX `sub_100E4B558` / `sub_100DE7764`. The behavior-oriented names
/// below are internal descriptions, not names from a public Apple API.
nonisolated enum AppleMusicLyricsDynamicSpring {
    private static let minimumSourceDuration: TimeInterval = 0.20
    private static let maximumSourceDuration: TimeInterval = 0.75
    private static let sourceDurationRange: TimeInterval = 0.55
    private static let maximumDampingRatio = 0.90
    private static let dampingRatioRange = 0.12
    private static let minimumPeriod: TimeInterval = 0.48
    private static let periodRange: TimeInterval = 0.27

    static func parameters(
        sourceDuration: TimeInterval
    ) -> LyricPhysicalSpringParameters {
        let cappedSourceDuration: TimeInterval
        if sourceDuration.isNaN {
            cappedSourceDuration = minimumSourceDuration
        } else {
            cappedSourceDuration = min(
                sourceDuration,
                maximumSourceDuration
            )
        }
        let progress = clampedUnitValue(
            (cappedSourceDuration - minimumSourceDuration)
                / sourceDurationRange
        )
        let dampingRatio = maximumDampingRatio
            - progress * dampingRatioRange
        let period = progress * periodRange + minimumPeriod
        let mass = 1.0
        let angularFrequency = 2 * Double.pi / period
        let stiffness = angularFrequency * angularFrequency
        let damping = dampingRatio
            * 2
            * sqrt(mass * stiffness)
        return LyricPhysicalSpringParameters(
            mass: mass,
            stiffness: stiffness,
            damping: damping
        )
    }

    private static func clampedUnitValue(_ value: Double) -> Double {
        guard !value.isNaN else { return 0 }
        return min(max(value, 0), 1)
    }
}
