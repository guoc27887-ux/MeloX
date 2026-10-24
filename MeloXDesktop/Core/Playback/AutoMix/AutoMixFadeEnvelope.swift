import Foundation

enum AutoMixFadeEnvelope {
    static func gains(
        at rawProgress: Double,
        curve: AutoMixFadeCurve
    ) -> (outgoing: Float, incoming: Float) {
        let progress = min(max(rawProgress, 0), 1)
        switch curve {
        case .equalPower:
            let smoothed =
                progress * progress * (3 - 2 * progress)
            return (
                Float(cos(smoothed * .pi / 2)),
                Float(sin(smoothed * .pi / 2))
            )
        case .smooth:
            let smoothed =
                progress * progress * (3 - 2 * progress)
            return (
                Float(1 - smoothed),
                Float(smoothed)
            )
        case .linear:
            return (
                Float(1 - progress),
                Float(progress)
            )
        }
    }
}
