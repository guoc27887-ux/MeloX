import SwiftUI

struct NowPlayingInterruptibleProgress: Equatable, Sendable {
    let id: UUID
    let startProgress: Double
    let targetProgress: Double
    let startedAt: ContinuousClock.Instant
    let delay: TimeInterval
    let duration: TimeInterval

    var isAnimating: Bool {
        startProgress != targetProgress
    }

    static func settled(
        at progress: Double,
        now: ContinuousClock.Instant
    ) -> Self {
        Self(
            id: UUID(),
            startProgress: progress,
            targetProgress: progress,
            startedAt: now,
            delay: 0,
            duration: 0
        )
    }

    func progress(at now: ContinuousClock.Instant) -> Double {
        let elapsed = startedAt.duration(to: now).timeInterval
        guard elapsed > delay else { return startProgress }
        guard duration > 0 else { return targetProgress }
        let fraction = min(max((elapsed - delay) / duration, 0), 1)
        return startProgress
            + (targetProgress - startProgress) * fraction
    }

    func remainingDuration(at now: ContinuousClock.Instant) -> TimeInterval {
        let elapsed = max(startedAt.duration(to: now).timeInterval, 0)
        return max(delay + duration - elapsed, 0)
    }

    func retargeted(
        to targetProgress: Double,
        fullDuration: TimeInterval,
        now: ContinuousClock.Instant,
        delay: TimeInterval = 0
    ) -> Self {
        let currentProgress = progress(at: now)
        let distance = abs(targetProgress - currentProgress)
        return Self(
            id: UUID(),
            startProgress: currentProgress,
            targetProgress: targetProgress,
            startedAt: now,
            delay: max(delay, 0),
            duration: max(fullDuration, 0) * distance
        )
    }
}

struct NowPlayingSpringProgressPresentation: Equatable, Sendable {
    let progress: Double
    let velocity: Double
}

struct NowPlayingInterruptibleSpringProgress: Equatable, Sendable {
    let id: UUID
    let startProgress: Double
    let targetProgress: Double
    /// Absolute progress units per second.
    let initialVelocity: Double
    let startedAt: ContinuousClock.Instant
    let settlementDuration: TimeInterval
    let spring: LyricPhysicalSpringParameters

    var isAnimating: Bool {
        startProgress != targetProgress
    }

    static func settled(
        at progress: Double,
        animationSpec: NowPlayingAnimationSpec,
        now: ContinuousClock.Instant
    ) -> Self {
        Self(
            id: UUID(),
            startProgress: progress,
            targetProgress: progress,
            initialVelocity: 0,
            startedAt: now,
            settlementDuration: 0,
            spring: springParameters(from: animationSpec)
        )
    }

    func presentation(
        at now: ContinuousClock.Instant
    ) -> NowPlayingSpringProgressPresentation {
        let distance = targetProgress - startProgress
        guard distance != 0 else {
            return NowPlayingSpringProgressPresentation(
                progress: targetProgress,
                velocity: 0
            )
        }
        let elapsed = max(
            startedAt.duration(to: now).timeInterval,
            0
        )
        guard settlementDuration > 0,
              elapsed < settlementDuration else {
            return NowPlayingSpringProgressPresentation(
                progress: targetProgress,
                velocity: 0
            )
        }
        let solver = Spring(
            mass: spring.mass,
            stiffness: spring.stiffness,
            damping: spring.damping,
            allowOverDamping: true
        )
        let progress = solver.value(
            fromValue: startProgress,
            toValue: targetProgress,
            initialVelocity: initialVelocity,
            time: elapsed
        )
        // The absolute from/to overload returns progress units per second.
        // Carry it directly so a reversal remains C1-continuous.
        let velocity = solver.velocity(
            fromValue: startProgress,
            toValue: targetProgress,
            initialVelocity: initialVelocity,
            time: elapsed
        )
        return NowPlayingSpringProgressPresentation(
            progress: progress.isFinite ? progress : targetProgress,
            velocity: velocity.isFinite ? velocity : 0
        )
    }

    func retargeted(
        to targetProgress: Double,
        animationSpec: NowPlayingAnimationSpec,
        now: ContinuousClock.Instant
    ) -> Self {
        let current = presentation(at: now)
        guard abs(targetProgress - current.progress) > 0.000_001 else {
            return .settled(
                at: targetProgress,
                animationSpec: animationSpec,
                now: now
            )
        }
        let initialVelocity = current.velocity.isFinite
            ? current.velocity
            : 0
        let spring = Self.springParameters(from: animationSpec)
        let solver = Spring(
            mass: spring.mass,
            stiffness: spring.stiffness,
            damping: spring.damping,
            allowOverDamping: true
        )
        let settlingDuration = solver.settlingDuration(
            fromValue: current.progress,
            toValue: targetProgress,
            initialVelocity: initialVelocity,
            epsilon: 0.001
        )
        return Self(
            id: UUID(),
            startProgress: current.progress,
            targetProgress: targetProgress,
            initialVelocity: initialVelocity,
            startedAt: now,
            settlementDuration:
                settlingDuration.isFinite
                    ? max(settlingDuration, 0)
                    : max(animationSpec.duration, 0),
            spring: spring
        )
    }

    func settled(
        at progress: Double,
        now: ContinuousClock.Instant
    ) -> Self {
        Self(
            id: UUID(),
            startProgress: progress,
            targetProgress: progress,
            initialVelocity: 0,
            startedAt: now,
            settlementDuration: 0,
            spring: spring
        )
    }

    func remainingDuration(at now: ContinuousClock.Instant) -> TimeInterval {
        let elapsed = max(startedAt.duration(to: now).timeInterval, 0)
        return max(settlementDuration - elapsed, 0)
    }

    private static func springParameters(
        from animationSpec: NowPlayingAnimationSpec
    ) -> LyricPhysicalSpringParameters {
        guard case let .interpolatingSpring(
            mass,
            stiffness,
            damping,
            _
        ) = animationSpec.curve else {
            return LyricPhysicalSpringParameters(
                mass: 1,
                stiffness: 350,
                damping: 40
            )
        }
        return LyricPhysicalSpringParameters(
            mass: mass,
            stiffness: stiffness,
            damping: damping
        )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1e18
    }
}
