import SwiftUI

/// Reconstructed from the macOS 26.6 Music 1.6.6 player presentation
/// controller.
///
/// The desktop host keeps its own layout, but it deliberately uses the same
/// page-state machine, opacity curves, and interruptible springs recovered
/// from the macOS implementation. In particular, Lyrics never has a page
/// translation: its presentation transform is scale-only.
struct DesktopNowPlayingAnimationSpec: Equatable, Sendable {
    enum Curve: Equatable, Sendable {
        case smooth
        case cubicBezier(
            x1: Double,
            y1: Double,
            x2: Double,
            y2: Double
        )
        case interpolatingSpring(
            mass: Double,
            stiffness: Double,
            damping: Double,
            initialVelocity: Double
        )
    }

    let curve: Curve
    let duration: TimeInterval
    let delay: TimeInterval

    init(
        _ curve: Curve,
        duration: TimeInterval,
        delay: TimeInterval = 0
    ) {
        self.curve = curve
        self.duration = duration
        self.delay = delay
    }

    var animation: Animation {
        let animation: Animation = switch curve {
        case .smooth:
            .smooth(duration: duration)
        case let .cubicBezier(x1, y1, x2, y2):
            .timingCurve(x1, y1, x2, y2, duration: duration)
        case let .interpolatingSpring(
            mass,
            stiffness,
            damping,
            initialVelocity
        ):
            .interpolatingSpring(
                mass: mass,
                stiffness: stiffness,
                damping: damping,
                initialVelocity: initialVelocity
            )
        }
        return delay > 0 ? animation.delay(delay) : animation
    }

    var totalDuration: TimeInterval {
        max(delay, 0) + max(duration, 0)
    }

    func transformedProgress(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        guard case let .cubicBezier(x1, y1, x2, y2) = curve else {
            return progress
        }
        return DesktopNowPlayingCubicBezier(
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2
        ).value(at: progress)
    }
}

private struct DesktopNowPlayingCubicBezier: Sendable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    func value(at linearProgress: Double) -> Double {
        let parameter = solveCurveX(linearProgress)
        return sampleCurve(parameter, control1: y1, control2: y2)
    }

    private func solveCurveX(_ x: Double) -> Double {
        var parameter = x
        for _ in 0..<8 {
            let error = sampleCurve(
                parameter,
                control1: x1,
                control2: x2
            ) - x
            let slope = sampleCurveDerivative(
                parameter,
                control1: x1,
                control2: x2
            )
            guard abs(slope) > 1e-7 else { break }
            parameter -= error / slope
            if parameter < 0 || parameter > 1 { break }
        }

        var lower = 0.0
        var upper = 1.0
        parameter = min(max(parameter, lower), upper)
        for _ in 0..<18 {
            let value = sampleCurve(
                parameter,
                control1: x1,
                control2: x2
            )
            if abs(value - x) < 1e-7 { break }
            if value < x {
                lower = parameter
            } else {
                upper = parameter
            }
            parameter = (lower + upper) * 0.5
        }
        return parameter
    }

    private func sampleCurve(
        _ parameter: Double,
        control1: Double,
        control2: Double
    ) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * control1
            + 3 * inverse * parameter * parameter * control2
            + parameter * parameter * parameter
    }

    private func sampleCurveDerivative(
        _ parameter: Double,
        control1: Double,
        control2: Double
    ) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * control1
            + 6 * inverse * parameter * (control2 - control1)
            + 3 * parameter * parameter * (1 - control2)
    }
}

struct DesktopNowPlayingInterruptibleProgress: Equatable, Sendable {
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

struct DesktopNowPlayingSpringPresentation: Equatable, Sendable {
    let progress: Double
    let velocity: Double
}

struct DesktopNowPlayingInterruptibleSpring: Equatable, Sendable {
    let id: UUID
    let startProgress: Double
    let targetProgress: Double
    let initialVelocity: Double
    let startedAt: ContinuousClock.Instant
    let settlementDuration: TimeInterval
    let spring: LyricPhysicalSpringParameters

    var isAnimating: Bool {
        startProgress != targetProgress
    }

    static func settled(
        at progress: Double,
        animationSpec: DesktopNowPlayingAnimationSpec,
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
    ) -> DesktopNowPlayingSpringPresentation {
        guard targetProgress != startProgress else {
            return DesktopNowPlayingSpringPresentation(
                progress: targetProgress,
                velocity: 0
            )
        }
        let elapsed = max(startedAt.duration(to: now).timeInterval, 0)
        guard settlementDuration > 0, elapsed < settlementDuration else {
            return DesktopNowPlayingSpringPresentation(
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
        let velocity = solver.velocity(
            fromValue: startProgress,
            toValue: targetProgress,
            initialVelocity: initialVelocity,
            time: elapsed
        )
        return DesktopNowPlayingSpringPresentation(
            progress: progress.isFinite ? progress : targetProgress,
            velocity: velocity.isFinite ? velocity : 0
        )
    }

    func retargeted(
        to targetProgress: Double,
        animationSpec: DesktopNowPlayingAnimationSpec,
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
            initialVelocity: current.velocity,
            epsilon: 0.001
        )
        return Self(
            id: UUID(),
            startProgress: current.progress,
            targetProgress: targetProgress,
            initialVelocity: current.velocity.isFinite ? current.velocity : 0,
            startedAt: now,
            settlementDuration: settlingDuration.isFinite
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
        from animationSpec: DesktopNowPlayingAnimationSpec
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

struct DesktopNowPlayingPageTransitionContext: Equatable, Identifiable, Sendable {
    let id: UUID
    let source: DesktopNowPlayingPage
    let destination: DesktopNowPlayingPage
    let isDirectLyricsQueueTransition: Bool
    let usesStagedLyricsEntrance: Bool
    let interruptsLyricsExit: Bool

    init(
        id: UUID = UUID(),
        source: DesktopNowPlayingPage,
        destination: DesktopNowPlayingPage,
        usesStagedLyricsEntrance: Bool,
        interruptsLyricsExit: Bool
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        isDirectLyricsQueueTransition =
            source == .lyrics && destination == .queue
            || source == .queue && destination == .lyrics
        self.usesStagedLyricsEntrance = usesStagedLyricsEntrance
        self.interruptsLyricsExit = interruptsLyricsExit
    }
}

struct DesktopNowPlayingPendingLyricsEntrance: Equatable, Sendable {
    let requestID: UUID
    let notBefore: ContinuousClock.Instant
    let fallbackAt: ContinuousClock.Instant
}

struct DesktopNowPlayingMotion: Equatable, Sendable {
    private static let pageSpringSettlementDuration = Spring(
        mass: 1,
        stiffness: 350,
        damping: 40,
        allowOverDamping: true
    ).settlingDuration(
        target: 1,
        initialVelocity: 0,
        epsilon: 0.001
    )

    let selection = DesktopNowPlayingAnimationSpec(.smooth, duration: 0.30)
    let directAlternate = DesktopNowPlayingAnimationSpec(.smooth, duration: 0.44)
    let artworkResize = DesktopNowPlayingAnimationSpec(.smooth, duration: 0.48)
    let lyricsSpatialPresentation = DesktopNowPlayingAnimationSpec(
        .interpolatingSpring(
            mass: 1,
            stiffness: 350,
            damping: 40,
            initialVelocity: 0
        ),
        duration: pageSpringSettlementDuration
    )
    let lyricsOpacityPresentation = DesktopNowPlayingAnimationSpec(
        .cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1),
        duration: 0.18
    )
    let lyricsSpatialDismissal = DesktopNowPlayingAnimationSpec(
        .interpolatingSpring(
            mass: 1,
            stiffness: 350,
            damping: 40,
            initialVelocity: 0
        ),
        duration: pageSpringSettlementDuration
    )
    let lyricsOpacityDismissal = DesktopNowPlayingAnimationSpec(
        .cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1),
        duration: 0.18
    )
    let queueSpatialPresentation = DesktopNowPlayingAnimationSpec(
        .interpolatingSpring(
            mass: 1,
            stiffness: 350,
            damping: 40,
            initialVelocity: 0
        ),
        duration: pageSpringSettlementDuration
    )
    let queueOpacityPresentation = DesktopNowPlayingAnimationSpec(
        .cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1),
        duration: 0.30,
        delay: 0.10
    )
    let queueSpatialDismissal = DesktopNowPlayingAnimationSpec(
        .interpolatingSpring(
            mass: 1,
            stiffness: 350,
            damping: 40,
            initialVelocity: 0
        ),
        duration: pageSpringSettlementDuration
    )
    let queueOpacityDismissal = DesktopNowPlayingAnimationSpec(
        .cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1),
        duration: 0.30
    )

    let lyricsPresentationScale: CGFloat = 0.90
    let queuePresentationScale: CGFloat = 0.90
    let directAlternateContentScale: CGFloat = 0.92
    let lyricsPresentationDelay: TimeInterval = 0.07
    let lyricsReadinessFallbackDelay: TimeInterval = 0.35
    let directAlternateSettlementDuration: TimeInterval = 0.46
    let standardSettlementDuration: TimeInterval = 0.50

    static let macOS26_6 = Self()

    func settlementDuration(
        for transition: DesktopNowPlayingPageTransitionContext
    ) -> TimeInterval {
        if transition.usesStagedLyricsEntrance {
            return max(
                lyricsSpatialPresentation.totalDuration,
                lyricsOpacityPresentation.totalDuration
            )
        }
        if transition.interruptsLyricsExit
            || transition.source == .lyrics
                && transition.destination != .lyrics {
            return max(
                lyricsSpatialDismissal.totalDuration,
                lyricsOpacityDismissal.totalDuration
            )
        }
        if transition.source == .queue || transition.destination == .queue {
            return max(
                queueSpatialPresentation.totalDuration,
                queueOpacityPresentation.totalDuration,
                queueSpatialDismissal.totalDuration,
                queueOpacityDismissal.totalDuration
            )
        }
        if transition.isDirectLyricsQueueTransition {
            return directAlternateSettlementDuration
        }
        return standardSettlementDuration
    }
}

struct DesktopNowPlayingTransitionCoordinator: Equatable {
    enum LyricsEntrancePhase: Equatable {
        case presented
        case pending(DesktopNowPlayingPendingLyricsEntrance)

        var isPresented: Bool {
            switch self {
            case .presented:
                true
            case .pending:
                false
            }
        }
    }

    private(set) var page: DesktopNowPlayingPage
    private(set) var transition: DesktopNowPlayingPageTransitionContext?
    private(set) var lyricsEntrancePhase: LyricsEntrancePhase = .presented
    private(set) var lyricsOpacityTransition: DesktopNowPlayingInterruptibleProgress
    private(set) var lyricsSpatialTransition: DesktopNowPlayingInterruptibleSpring
    private(set) var queueOpacityTransition: DesktopNowPlayingInterruptibleProgress
    private(set) var queueSpatialTransition: DesktopNowPlayingInterruptibleSpring

    init(
        initialPage: DesktopNowPlayingPage,
        motion: DesktopNowPlayingMotion = .macOS26_6,
        now: ContinuousClock.Instant = .now
    ) {
        page = initialPage
        lyricsOpacityTransition = .settled(
            at: initialPage == .lyrics ? 1 : 0,
            now: now
        )
        lyricsSpatialTransition = .settled(
            at: initialPage == .lyrics ? 1 : 0,
            animationSpec: motion.lyricsSpatialPresentation,
            now: now
        )
        queueOpacityTransition = .settled(
            at: initialPage == .queue ? 1 : 0,
            now: now
        )
        queueSpatialTransition = .settled(
            at: initialPage == .queue ? 1 : 0,
            animationSpec: motion.queueSpatialPresentation,
            now: now
        )
    }

    var isLyricsEntrancePresented: Bool {
        lyricsEntrancePhase.isPresented
    }

    var pendingLyricsEntrance: DesktopNowPlayingPendingLyricsEntrance? {
        guard case let .pending(entrance) = lyricsEntrancePhase else {
            return nil
        }
        return entrance
    }

    func activeMotionRemainingDuration(
        at now: ContinuousClock.Instant = .now
    ) -> TimeInterval {
        max(
            lyricsOpacityTransition.remainingDuration(at: now),
            lyricsSpatialTransition.remainingDuration(at: now),
            queueOpacityTransition.remainingDuration(at: now),
            queueSpatialTransition.remainingDuration(at: now)
        )
    }

    mutating func select(
        _ destination: DesktopNowPlayingPage,
        usesAppleMusicLyrics: Bool,
        motion: DesktopNowPlayingMotion,
        now: ContinuousClock.Instant = .now
    ) {
        let source = page
        guard source != destination else { return }

        let startsLyricsEntrance = source != .lyrics
            && destination == .lyrics
            && usesAppleMusicLyrics
        let currentLyricsOpacity = lyricsOpacityTransition.progress(at: now)
        let interruptsActiveLyricsExit = startsLyricsEntrance
            && lyricsOpacityTransition.targetProgress < 1
            && currentLyricsOpacity > 0.000_1
        let requestID = UUID()
        let context = DesktopNowPlayingPageTransitionContext(
            id: requestID,
            source: source,
            destination: destination,
            usesStagedLyricsEntrance:
                startsLyricsEntrance && !interruptsActiveLyricsExit,
            interruptsLyricsExit: interruptsActiveLyricsExit
        )

        let currentQueueOpacity = queueOpacityTransition.progress(at: now)
        if destination == .queue {
            let reversesQueueExit = queueOpacityTransition.targetProgress < 1
                && currentQueueOpacity > 0.000_1
            queueOpacityTransition = queueOpacityTransition.retargeted(
                to: 1,
                fullDuration: motion.queueOpacityPresentation.duration,
                now: now,
                delay: reversesQueueExit
                    ? 0
                    : motion.queueOpacityPresentation.delay
            )
            queueSpatialTransition = queueSpatialTransition.retargeted(
                to: 1,
                animationSpec: motion.queueSpatialPresentation,
                now: now
            )
        } else if source == .queue {
            queueOpacityTransition = queueOpacityTransition.retargeted(
                to: 0,
                fullDuration: motion.queueOpacityDismissal.duration,
                now: now
            )
            queueSpatialTransition = queueSpatialTransition.retargeted(
                to: 0,
                animationSpec: motion.queueSpatialDismissal,
                now: now
            )
        }

        if !usesAppleMusicLyrics {
            lyricsEntrancePhase = .presented
            lyricsOpacityTransition = .settled(
                at: destination == .lyrics ? 1 : 0,
                now: now
            )
            lyricsSpatialTransition = .settled(
                at: destination == .lyrics ? 1 : 0,
                animationSpec: motion.lyricsSpatialPresentation,
                now: now
            )
        } else if context.usesStagedLyricsEntrance {
            lyricsEntrancePhase = .pending(
                DesktopNowPlayingPendingLyricsEntrance(
                    requestID: requestID,
                    notBefore: now.advanced(
                        by: .seconds(motion.lyricsPresentationDelay)
                    ),
                    fallbackAt: now.advanced(
                        by: .seconds(motion.lyricsReadinessFallbackDelay)
                    )
                )
            )
            lyricsOpacityTransition = .settled(at: 0, now: now)
            lyricsSpatialTransition = .settled(
                at: 0,
                animationSpec: motion.lyricsSpatialPresentation,
                now: now
            )
        } else {
            lyricsEntrancePhase = .presented
            if destination == .lyrics {
                lyricsOpacityTransition = lyricsOpacityTransition.retargeted(
                    to: 1,
                    fullDuration: motion.lyricsOpacityPresentation.duration,
                    now: now
                )
                lyricsSpatialTransition = lyricsSpatialTransition.retargeted(
                    to: 1,
                    animationSpec: motion.lyricsSpatialPresentation,
                    now: now
                )
            } else if source == .lyrics {
                lyricsOpacityTransition = lyricsOpacityTransition.retargeted(
                    to: 0,
                    fullDuration: motion.lyricsOpacityDismissal.duration,
                    now: now
                )
                lyricsSpatialTransition = lyricsSpatialTransition.retargeted(
                    to: 0,
                    animationSpec: motion.lyricsSpatialDismissal,
                    now: now
                )
            }
        }

        transition = context
        page = destination
    }

    mutating func presentLyricsEntrance(
        requestID: UUID,
        motion: DesktopNowPlayingMotion,
        now: ContinuousClock.Instant = .now
    ) {
        guard transition?.id == requestID,
              transition?.usesStagedLyricsEntrance == true,
              case let .pending(entrance) = lyricsEntrancePhase,
              entrance.requestID == requestID else {
            return
        }
        lyricsEntrancePhase = .presented
        lyricsOpacityTransition = lyricsOpacityTransition.retargeted(
            to: 1,
            fullDuration: motion.lyricsOpacityPresentation.duration,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.retargeted(
            to: 1,
            animationSpec: motion.lyricsSpatialPresentation,
            now: now
        )
    }

    mutating func settleTransition(
        requestID: UUID,
        now: ContinuousClock.Instant = .now
    ) {
        guard transition?.id == requestID,
              lyricsEntrancePhase.isPresented else {
            return
        }
        transition = nil
        lyricsOpacityTransition = .settled(
            at: lyricsOpacityTransition.targetProgress,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.settled(
            at: lyricsSpatialTransition.targetProgress,
            now: now
        )
        queueOpacityTransition = .settled(
            at: queueOpacityTransition.targetProgress,
            now: now
        )
        queueSpatialTransition = queueSpatialTransition.settled(
            at: queueSpatialTransition.targetProgress,
            now: now
        )
    }

    mutating func reset(
        to page: DesktopNowPlayingPage,
        now: ContinuousClock.Instant = .now
    ) {
        self.page = page
        transition = nil
        lyricsEntrancePhase = .presented
        lyricsOpacityTransition = .settled(
            at: page == .lyrics ? 1 : 0,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.settled(
            at: page == .lyrics ? 1 : 0,
            now: now
        )
        queueOpacityTransition = .settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
        queueSpatialTransition = queueSpatialTransition.settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
    }
}

private struct DesktopNowPlayingPanelPresentation: ViewModifier {
    let opacityTransition: DesktopNowPlayingInterruptibleProgress
    let spatialTransition: DesktopNowPlayingInterruptibleSpring
    let opacitySpec: DesktopNowPlayingAnimationSpec
    let presentationScale: CGFloat
    let reducesMotion: Bool

    func body(content: Content) -> some View {
        TimelineView(
            .animation(
                paused: reducesMotion || (!opacityTransition.isAnimating
                    && !spatialTransition.isAnimating)
            )
        ) { _ in
            let now = ContinuousClock.now
            let opacityProgress = reducesMotion
                ? opacityTransition.targetProgress
                : opacityTransition.progress(at: now)
            let spatialProgress = reducesMotion
                ? spatialTransition.targetProgress
                : spatialTransition.presentation(at: now).progress
            let scale = presentationScale
                + (1 - presentationScale) * CGFloat(spatialProgress)

            content
                .scaleEffect(scale, anchor: .center)
                .opacity(opacitySpec.transformedProgress(opacityProgress))
        }
    }
}

extension View {
    func desktopNowPlayingPanelPresentation(
        opacityTransition: DesktopNowPlayingInterruptibleProgress,
        spatialTransition: DesktopNowPlayingInterruptibleSpring,
        opacitySpec: DesktopNowPlayingAnimationSpec,
        presentationScale: CGFloat,
        reducesMotion: Bool
    ) -> some View {
        modifier(
            DesktopNowPlayingPanelPresentation(
                opacityTransition: opacityTransition,
                spatialTransition: spatialTransition,
                opacitySpec: opacitySpec,
                presentationScale: presentationScale,
                reducesMotion: reducesMotion
            )
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
