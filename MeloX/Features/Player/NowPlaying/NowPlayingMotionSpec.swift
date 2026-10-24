import SwiftUI

enum NowPlayingPage: String, Hashable, Sendable {
    case artwork
    case lyrics
    case queue
}

struct NowPlayingPageVisualState: Equatable, Sendable {
    let offsetY: CGFloat
    let scale: CGFloat
    let opacity: Double
    let blurRadius: CGFloat

    static let identity = NowPlayingPageVisualState(
        offsetY: 0,
        scale: 1,
        opacity: 1,
        blurRadius: 0
    )

    var spatialState: NowPlayingPageSpatialState {
        NowPlayingPageSpatialState(
            offsetY: offsetY,
            scale: scale
        )
    }
}

struct NowPlayingPageSpatialState: Equatable, Sendable {
    let offsetY: CGFloat
    let scale: CGFloat
}

struct NowPlayingAnimationSpec: Equatable, Sendable {
    enum Curve: Equatable, Sendable {
        case smooth
        case easeInOut
        case spring(bounce: Double)
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
    /// Curve duration, or the coordinator's settlement horizon for a
    /// durationless physical spring.
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
        let baseAnimation: Animation = switch curve {
        case .smooth:
            .smooth(duration: duration)
        case .easeInOut:
            .easeInOut(duration: duration)
        case let .spring(bounce):
            .spring(duration: duration, bounce: bounce)
        case let .cubicBezier(x1, y1, x2, y2):
            .timingCurve(
                x1,
                y1,
                x2,
                y2,
                duration: duration
            )
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
        return delay > 0
            ? baseAnimation.delay(delay)
            : baseAnimation
    }

    var totalDuration: TimeInterval {
        max(delay, 0) + max(duration, 0)
    }

    func transformedProgress(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        guard case let .cubicBezier(x1, y1, x2, y2) = curve else {
            return progress
        }
        return NowPlayingCubicBezierTimingCurve(
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2
        ).value(at: progress)
    }
}

private struct NowPlayingCubicBezierTimingCurve: Sendable {
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

enum NowPlayingInterfaceLayer: Hashable, Sendable {
    case progress
    case transport
    case volume
    case pageSelector
}

struct NowPlayingMotionSpec: Equatable, Sendable {
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

    struct PageMotion: Equatable, Sendable {
        let selection: NowPlayingAnimationSpec
        let directAlternate: NowPlayingAnimationSpec
        let outgoing: NowPlayingAnimationSpec
        let incoming: NowPlayingAnimationSpec
        let songHeaderIncoming: NowPlayingAnimationSpec
        let delayedResidentEntrance: NowPlayingAnimationSpec
        let lyricsSpatialPresentation: NowPlayingAnimationSpec
        let lyricsOpacityPresentation: NowPlayingAnimationSpec
        let lyricsSpatialDismissal: NowPlayingAnimationSpec
        let lyricsOpacityDismissal: NowPlayingAnimationSpec
        let queueSpatialPresentation: NowPlayingAnimationSpec
        let queueOpacityPresentation: NowPlayingAnimationSpec
        let queueSpatialDismissal: NowPlayingAnimationSpec
        let queueOpacityDismissal: NowPlayingAnimationSpec
        let artworkResize: NowPlayingAnimationSpec

        let directAlternateContentScale: CGFloat
        let lyricsPresentationScale: CGFloat
        let queuePresentationScale: CGFloat
        let lyricsTravel: CGFloat
        let queueTravel: CGFloat
        let artworkDetailsTravel: CGFloat
        let songHeaderTravel: CGFloat
        let lyricsPresentationDelay: TimeInterval
        let lyricsReadinessFallbackDelay: TimeInterval
        let hiddenQueueSettlementDuration: TimeInterval
        let directAlternateSettlementDuration: TimeInterval
        let standardSettlementDuration: TimeInterval

        func residentLyricsState(
            selectedPage: NowPlayingPage,
            transition: NowPlayingTransitionContext?,
            isEntrancePresented: Bool
        ) -> NowPlayingPageVisualState {
            if selectedPage == .lyrics {
                let waitsForEntrance =
                    transition?.usesStagedLyricsEntrance == true
                    && !isEntrancePresented
                return NowPlayingPageVisualState(
                    offsetY: waitsForEntrance ? lyricsTravel : 0,
                    scale:
                        waitsForEntrance
                            ? lyricsPresentationScale
                            : 1,
                    opacity: waitsForEntrance ? 0 : 1,
                    blurRadius: 0
                )
            }

            return NowPlayingPageVisualState(
                offsetY: lyricsTravel,
                scale: lyricsPresentationScale,
                opacity: 0,
                blurRadius: 0
            )
        }

        func residentLyricsSpatialAnimation(
            for transition: NowPlayingTransitionContext?
        ) -> NowPlayingAnimationSpec? {
            guard let transition else { return nil }
            if transition.source == .lyrics,
               transition.destination != .lyrics {
                return lyricsSpatialDismissal
            }
            if transition.source != .lyrics,
               transition.destination == .lyrics {
                return transition.interruptsLyricsExit
                    ? lyricsSpatialDismissal
                    : lyricsSpatialPresentation
            }
            return nil
        }

        func residentLyricsOpacityAnimation(
            for transition: NowPlayingTransitionContext?
        ) -> NowPlayingAnimationSpec? {
            guard let transition else { return nil }
            if transition.source == .lyrics,
               transition.destination != .lyrics {
                return lyricsOpacityDismissal
            }
            if transition.source != .lyrics,
               transition.destination == .lyrics {
                return transition.interruptsLyricsExit
                    ? lyricsOpacityDismissal
                    : lyricsOpacityPresentation
            }
            return nil
        }

        func residentQueueState(
            selectedPage: NowPlayingPage,
            transition: NowPlayingTransitionContext?
        ) -> NowPlayingPageVisualState {
            let staysAtArtworkEdge =
                selectedPage == .artwork
                && transition?.entersFromHiddenQueue != true
            return NowPlayingPageVisualState(
                offsetY: staysAtArtworkEdge ? queueTravel : 0,
                scale:
                    selectedPage == .lyrics
                        ? directAlternateContentScale
                        : 1,
                opacity: selectedPage == .queue ? 1 : 0,
                blurRadius: 0
            )
        }

        func settlementDuration(
            for transition: NowPlayingTransitionContext
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
            if transition.source == .queue
                || transition.destination == .queue {
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
            if transition.entersFromHiddenQueue {
                return hiddenQueueSettlementDuration
            }
            return standardSettlementDuration
        }
    }

    struct InterfaceMotion: Equatable, Sendable {
        struct LayerMotion: Equatable, Sendable {
            let hiddenOffset: CGFloat
            let showDelay: TimeInterval
            let hideDelay: TimeInterval
        }

        let coreShow: NowPlayingAnimationSpec
        let coreHide: NowPlayingAnimationSpec
        let utilityShow: NowPlayingAnimationSpec
        let utilityHide: NowPlayingAnimationSpec
        let controlDuration: TimeInterval
        let utilityHiddenOffset: CGFloat
        let utilityHiddenScale: CGFloat
        let progress: LayerMotion
        let transport: LayerMotion
        let volume: LayerMotion
        let pageSelector: LayerMotion

        func layerMotion(
            for layer: NowPlayingInterfaceLayer
        ) -> LayerMotion {
            switch layer {
            case .progress:
                progress
            case .transport:
                transport
            case .volume:
                volume
            case .pageSelector:
                pageSelector
            }
        }

        func controlAnimation(
            for layer: NowPlayingInterfaceLayer,
            isVisible: Bool
        ) -> NowPlayingAnimationSpec {
            let layerMotion = layerMotion(for: layer)
            return NowPlayingAnimationSpec(
                .smooth,
                duration: controlDuration,
                delay:
                    isVisible
                        ? layerMotion.showDelay
                        : layerMotion.hideDelay
            )
        }
    }

    let page: PageMotion
    let interface: InterfaceMotion

    static let appleMusic26 = NowPlayingMotionSpec(
        page: PageMotion(
            selection: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.30
            ),
            directAlternate: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.44
            ),
            outgoing: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.24
            ),
            incoming: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.22,
                delay: 0.07
            ),
            songHeaderIncoming: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.40,
                delay: 0.08
            ),
            delayedResidentEntrance: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.34,
                delay: 0.11
            ),
            // Values recovered from the iOS 26 Music presentation animator.
            lyricsSpatialPresentation: NowPlayingAnimationSpec(
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 350,
                    damping: 40,
                    initialVelocity: 0
                ),
                duration: pageSpringSettlementDuration
            ),
            lyricsOpacityPresentation: NowPlayingAnimationSpec(
                .cubicBezier(
                    x1: 0.42,
                    y1: 0,
                    x2: 0.58,
                    y2: 1
                ),
                duration: 0.18
            ),
            lyricsSpatialDismissal: NowPlayingAnimationSpec(
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 350,
                    damping: 40,
                    initialVelocity: 0
                ),
                duration: pageSpringSettlementDuration
            ),
            lyricsOpacityDismissal: NowPlayingAnimationSpec(
                .cubicBezier(
                    x1: 0.42,
                    y1: 0,
                    x2: 0.58,
                    y2: 1
                ),
                duration: 0.18
            ),
            // Regular Now Playing queue animator recovered from presentQueue.
            queueSpatialPresentation: NowPlayingAnimationSpec(
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 350,
                    damping: 40,
                    initialVelocity: 0
                ),
                duration: pageSpringSettlementDuration
            ),
            queueOpacityPresentation: NowPlayingAnimationSpec(
                .cubicBezier(
                    x1: 0.42,
                    y1: 0,
                    x2: 0.58,
                    y2: 1
                ),
                duration: 0.30,
                delay: 0.10
            ),
            queueSpatialDismissal: NowPlayingAnimationSpec(
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 350,
                    damping: 40,
                    initialVelocity: 0
                ),
                duration: pageSpringSettlementDuration
            ),
            queueOpacityDismissal: NowPlayingAnimationSpec(
                .cubicBezier(
                    x1: 0.42,
                    y1: 0,
                    x2: 0.58,
                    y2: 1
                ),
                duration: 0.30
            ),
            artworkResize: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.48
            ),
            directAlternateContentScale: 0.92,
            lyricsPresentationScale: 0.90,
            queuePresentationScale: 0.90,
            // The recovered lyrics-mode transform contains scale only. It
            // does not translate the presented lyrics view vertically.
            lyricsTravel: 0,
            queueTravel: 0,
            artworkDetailsTravel: -300,
            songHeaderTravel: 40,
            lyricsPresentationDelay: 0.07,
            lyricsReadinessFallbackDelay: 0.35,
            hiddenQueueSettlementDuration: 0.42,
            directAlternateSettlementDuration: 0.46,
            standardSettlementDuration: 0.50
        ),
        interface: InterfaceMotion(
            coreShow: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.34
            ),
            coreHide: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.34
            ),
            utilityShow: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.24
            ),
            utilityHide: NowPlayingAnimationSpec(
                .smooth,
                duration: 0.24,
                delay: 0.10
            ),
            controlDuration: 0.24,
            utilityHiddenOffset: 64,
            utilityHiddenScale: 0.82,
            progress: InterfaceMotion.LayerMotion(
                hiddenOffset: 180,
                showDelay: 0.025,
                hideDelay: 0.075
            ),
            transport: InterfaceMotion.LayerMotion(
                hiddenOffset: 165,
                showDelay: 0.05,
                hideDelay: 0.05
            ),
            volume: InterfaceMotion.LayerMotion(
                hiddenOffset: 148,
                showDelay: 0.075,
                hideDelay: 0.025
            ),
            pageSelector: InterfaceMotion.LayerMotion(
                hiddenOffset: 128,
                showDelay: 0.10,
                hideDelay: 0
            )
        )
    )
}
