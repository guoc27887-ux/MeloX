import SwiftUI

struct WatchLyricRendererStyle {
    let glowRadius: CGFloat
    let glowOpacity: Double
    let glowsLongTonesOnly: Bool
    let unplayedOpacity: Double
    let maximumUnplayedBlurRadius: CGFloat
    let playedRise: CGFloat
    let maximumLongToneScale: CGFloat
    let longToneExpansionPadding: CGFloat
    let highlightGradientWidth: CGFloat
    let highlightGradientReduction: CGFloat
    let liftMode: WatchLyricTimingMode
    let longToneDetectionMode: WatchLyricTimingMode
    let longToneDurationThreshold: TimeInterval

    var drawsGlow: Bool {
        glowRadius > 0 && glowOpacity > 0
    }
}

@available(watchOS 11.0, *)
struct WatchLyricTextRenderer: TextRenderer {
    static let glowTailDuration: TimeInterval = 0.55

    var playbackTime: TimeInterval
    let style: WatchLyricRendererStyle
    let appliesTimingEffects: Bool

    var animatableData: Double {
        get { playbackTime }
        set { playbackTime = newValue }
    }

    var displayPadding: EdgeInsets {
        let glowPadding = style.glowRadius
            * Metrics.displayPaddingMultiplier
        let expansionPadding = max(
            style.longToneExpansionPadding,
            0
        )
        return EdgeInsets(
            top:
                glowPadding
                + max(style.playedRise, 0)
                + expansionPadding,
            leading: glowPadding + expansionPadding,
            bottom: glowPadding + expansionPadding,
            trailing: glowPadding + expansionPadding
        )
    }

    func draw(
        layout: Text.Layout,
        in context: inout GraphicsContext
    ) {
        guard appliesTimingEffects else {
            for line in layout {
                context.draw(line)
            }
            return
        }

        for line in layout {
            let revealMask = lineRevealMask(for: line)
            for run in line {
                draw(
                    run,
                    revealMask: revealMask,
                    in: &context
                )
            }
        }
    }

    private func lineRevealMask(
        for line: Text.Layout.Line
    ) -> LineRevealMask? {
        let timedRuns = line.compactMap { run -> TimedRun? in
            guard let timing =
                    run[WatchLyricTimingTextAttribute.self],
                  !timing.isWhitespace else {
                return nil
            }
            let bounds = run.typographicBounds.rect
            guard bounds.width.isFinite, bounds.width > 0 else {
                return nil
            }
            return TimedRun(
                timing: timing,
                bounds: bounds,
                layoutDirection: run.layoutDirection
            )
        }
        guard let firstRun = timedRuns.min(
            by: { $0.timing.startTime < $1.timing.startTime }
        ),
        playbackTime >= firstRun.timing.startTime else {
            return nil
        }

        let activeRun = timedRuns.first {
            playbackTime >= $0.timing.startTime
                && playbackTime < $0.timing.endTime
        }
        let completedRun = timedRuns
            .filter { playbackTime >= $0.timing.endTime }
            .max { $0.timing.endTime < $1.timing.endTime }
        let referenceRun = activeRun ?? completedRun ?? firstRun
        let direction = referenceRun.layoutDirection
        let frontX: CGFloat

        if let activeRun {
            let progress = highlightRevealProgress(
                for: activeRun.timing
            )
            if direction == .rightToLeft {
                frontX = activeRun.bounds.maxX
                    - activeRun.bounds.width * CGFloat(progress)
            } else {
                frontX = activeRun.bounds.minX
                    + activeRun.bounds.width * CGFloat(progress)
            }
        } else if direction == .rightToLeft {
            frontX = referenceRun.bounds.minX
        } else {
            frontX = referenceRun.bounds.maxX
        }

        let averageGlyphWidth = timedRuns.reduce(CGFloat.zero) {
            $0 + $1.bounds.width
        } / CGFloat(max(timedRuns.count, 1))
        return LineRevealMask(
            frontX: frontX,
            featherWidth: max(
                averageGlyphWidth
                    * max(style.highlightGradientWidth, 0.1),
                Metrics.minimumRevealFeatherWidth
            ),
            gradient: highlightGradient(
                reduction: style.highlightGradientReduction,
                layoutDirection: direction
            ),
            layoutDirection: direction
        )
    }

    private func draw(
        _ run: Text.Layout.Run,
        revealMask: LineRevealMask?,
        in context: inout GraphicsContext
    ) {
        guard let timing =
                run[WatchLyricTimingTextAttribute.self] else {
            context.draw(run)
            return
        }

        let state = visualState(for: timing)
        let bounds = run.typographicBounds.rect
        var runContext = context
        applyLift(
            to: &runContext,
            progress: state.liftProgress
        )
        if state.expansionScale != 1
            || state.emphasis.envelope > 0 {
            applyExpansion(
                to: &runContext,
                scale: state.expansionScale,
                anchor: CGPoint(
                    x: bounds.midX,
                    y: bounds.midY
                ),
                offset: state.emphasis.expansionOffset(
                    layoutDirection: run.layoutDirection,
                    glyphBounds: bounds
                )
            )
        }

        drawUnplayed(
            run,
            blurRadius: state.unplayedBlurRadius,
            in: &runContext
        )
        guard let revealMask else { return }
        drawPlayed(
            run,
            revealMask: revealMask,
            glowStrength: state.glowStrength,
            in: &runContext
        )
    }

    private func visualState(
        for timing: WatchLyricTimingTextAttribute
    ) -> RunVisualState {
        let rawProgress = playedProgress(for: timing)
        let emphasis = WatchLyricLongToneEmphasis.state(
            playbackTime: playbackTime,
            timing: timing,
            detectionMode: style.longToneDetectionMode,
            durationThreshold: style.longToneDurationThreshold
        )
        let glowStrength: Double
        if style.drawsGlow, emphasis.isLongTone {
            glowStrength = emphasis.envelope * emphasis.glowAmount
        } else if style.drawsGlow,
                  !style.glowsLongTonesOnly,
                  rawProgress > 0 {
            glowStrength = ordinaryGlowStrength(
                for: timing,
                rawProgress: rawProgress
            )
        } else {
            glowStrength = 0
        }

        return RunVisualState(
            liftProgress: liftProgress(for: timing),
            expansionScale:
                1
                + (max(style.maximumLongToneScale, 1) - 1)
                    * CGFloat(
                        emphasis.envelope
                            * emphasis.expansionAmount
                    ),
            emphasis: emphasis,
            unplayedBlurRadius: unplayedBlurRadius(for: timing),
            glowStrength: glowStrength
        )
    }

    private func liftProgress(
        for timing: WatchLyricTimingTextAttribute
    ) -> Double {
        let startTime = style.liftMode == .word
            ? timing.wordStartTime
            : timing.startTime
        let endTime = style.liftMode == .word
            ? timing.wordEndTime
            : timing.endTime
        guard playbackTime > startTime else { return 0 }

        let transitionEndTime =
            endTime + Metrics.liftContinuationDuration
        let transitionDuration = transitionEndTime - startTime
        guard transitionDuration > 0 else { return 1 }
        return smootherStep(
            (playbackTime - startTime) / transitionDuration
        )
    }

    private func applyLift(
        to context: inout GraphicsContext,
        progress: Double
    ) {
        let offset = -max(style.playedRise, 0)
            * CGFloat(unitProgress(progress))
        guard offset != 0 else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        translationX: 0,
                        y: offset
                    )
                )
            )
        )
    }

    private func applyExpansion(
        to context: inout GraphicsContext,
        scale: CGFloat,
        anchor: CGPoint,
        offset: CGSize
    ) {
        let scale = max(scale, 1)
        guard scale != 1 || offset != .zero else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        a: scale,
                        b: 0,
                        c: 0,
                        d: scale,
                        tx:
                            anchor.x * (1 - scale)
                            + offset.width,
                        ty:
                            anchor.y * (1 - scale)
                            + offset.height
                    )
                )
            )
        )
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        blurRadius: CGFloat,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        unplayedContext.opacity = style.unplayedOpacity
        if blurRadius > 0 {
            unplayedContext.addFilter(.blur(radius: blurRadius))
        }
        unplayedContext.draw(run)
    }

    private func drawPlayed(
        _ run: Text.Layout.Run,
        revealMask: LineRevealMask,
        glowStrength: Double,
        in context: inout GraphicsContext
    ) {
        context.drawLayer { layer in
            if glowStrength > 0 {
                drawGlow(
                    for: run,
                    revealMask: revealMask,
                    strength: glowStrength,
                    in: &layer
                )
            }
            drawRevealed(
                run,
                revealMask: revealMask,
                in: &layer
            )
        }
    }

    private func drawGlow(
        for run: Text.Layout.Run,
        revealMask: LineRevealMask,
        strength: Double,
        in context: inout GraphicsContext
    ) {
        let baseOpacity = style.glowOpacity * strength
        drawGlowLayer(
            for: run,
            revealMask: revealMask,
            radius:
                style.glowRadius
                * Metrics.outerGlowRadiusMultiplier,
            opacity:
                min(
                    baseOpacity
                        * Metrics.outerGlowOpacityMultiplier,
                    1
                ),
            in: &context
        )
        drawGlowLayer(
            for: run,
            revealMask: revealMask,
            radius:
                style.glowRadius
                * Metrics.innerGlowRadiusMultiplier,
            opacity: min(baseOpacity, 1),
            in: &context
        )
    }

    private func drawGlowLayer(
        for run: Text.Layout.Run,
        revealMask: LineRevealMask,
        radius: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        guard radius > 0, opacity > 0 else { return }
        var glowContext = context
        glowContext.opacity = opacity
        glowContext.blendMode = .plusLighter
        glowContext.addFilter(.blur(radius: radius))
        drawRevealed(
            run,
            revealMask: revealMask,
            in: &glowContext
        )
    }

    private func drawRevealed(
        _ run: Text.Layout.Run,
        revealMask: LineRevealMask,
        in context: inout GraphicsContext
    ) {
        let bounds = run.typographicBounds.rect
        guard bounds.width > 0, bounds.height > 0 else { return }

        let startPoint: CGPoint
        let endPoint: CGPoint
        if revealMask.layoutDirection == .rightToLeft {
            startPoint = CGPoint(
                x: revealMask.frontX - revealMask.featherWidth,
                y: bounds.midY
            )
            endPoint = CGPoint(
                x: revealMask.frontX,
                y: bounds.midY
            )
        } else {
            startPoint = CGPoint(
                x: revealMask.frontX,
                y: bounds.midY
            )
            endPoint = CGPoint(
                x: revealMask.frontX + revealMask.featherWidth,
                y: bounds.midY
            )
        }

        context.clipToLayer { maskContext in
            maskContext.fill(
                Path(bounds),
                with: .linearGradient(
                    revealMask.gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
        }
        context.draw(run)
    }

    private func highlightGradient(
        reduction: CGFloat,
        layoutDirection: LayoutDirection
    ) -> Gradient {
        let reduction = min(max(Double(reduction), 0), 1)
        let stops = (0...Metrics.highlightGradientStopCount)
            .map { index in
                let location = Double(index)
                    / Double(Metrics.highlightGradientStopCount)
                let distanceFromFront =
                    layoutDirection == .rightToLeft
                        ? 1 - location
                        : location
                let remainingHighlight = 1 - distanceFromFront
                return Gradient.Stop(
                    color: .white.opacity(
                        remainingHighlight
                            * (
                                1
                                    - reduction
                                        * distanceFromFront
                            )
                    ),
                    location: CGFloat(location)
                )
            }
        return Gradient(stops: stops)
    }

    private func highlightRevealProgress(
        for timing: WatchLyricTimingTextAttribute
    ) -> Double {
        let duration = timing.endTime - timing.startTime
        let rawProgress = playedProgress(for: timing)
        let regularProgress = smootherStep(rawProgress)
        guard duration
                > Metrics.highlightAttackDuration
                    + Metrics.highlightReleaseDuration,
              WatchLyricLongToneEmphasis.isLongTone(
                  timing: timing,
                  detectionMode: style.longToneDetectionMode,
                  durationThreshold:
                      style.longToneDurationThreshold
              ) else {
            return regularProgress
        }

        let elapsed = max(
            playbackTime - timing.startTime,
            0
        )
        let attackProgress = smootherStep(
            elapsed / Metrics.highlightAttackDuration
        )
        let releaseStartTime =
            timing.endTime - Metrics.highlightReleaseDuration
        let releaseProgress = smootherStep(
            (playbackTime - releaseStartTime)
                / Metrics.highlightReleaseDuration
        )
        return unitProgress(
            Metrics.highlightAttackContribution * attackProgress
                + Metrics.highlightContinuousContribution
                    * rawProgress
                + Metrics.highlightReleaseContribution
                    * releaseProgress
        )
    }

    private func unplayedBlurRadius(
        for timing: WatchLyricTimingTextAttribute
    ) -> CGFloat {
        guard style.maximumUnplayedBlurRadius > 0,
              playbackTime < timing.startTime else {
            return 0
        }
        let distance = smootherStep(
            (timing.startTime - playbackTime)
                / Metrics.unplayedBlurLeadDuration
        )
        let fraction =
            Metrics.minimumUnplayedBlurFraction
            + (1 - Metrics.minimumUnplayedBlurFraction)
                * distance
        return style.maximumUnplayedBlurRadius
            * CGFloat(fraction)
    }

    private func playedProgress(
        for timing: WatchLyricTimingTextAttribute
    ) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }
        let duration = timing.endTime - timing.startTime
        guard duration > 0 else { return 1 }
        return unitProgress(
            (playbackTime - timing.startTime) / duration
        )
    }

    private func ordinaryGlowStrength(
        for timing: WatchLyricTimingTextAttribute,
        rawProgress: Double
    ) -> Double {
        if playbackTime <= timing.endTime {
            let attack = smootherStep(
                rawProgress / Metrics.glowAttackProgress
            )
            let breath = Metrics.minimumGlowStrength
                + (1 - Metrics.minimumGlowStrength)
                    * sin(.pi * rawProgress)
            return attack
                * breath
                * Metrics.ordinaryGlowStrengthMultiplier
        }

        let tailProgress =
            (playbackTime - timing.endTime)
            / Self.glowTailDuration
        guard tailProgress < 1 else { return 0 }
        return (1 - smootherStep(tailProgress))
            * Metrics.minimumGlowStrength
            * Metrics.ordinaryGlowStrengthMultiplier
    }

    private func smootherStep(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private func unitProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@available(watchOS 11.0, *)
struct WatchLyricRomanizationTextRenderer: TextRenderer {
    var playbackTime: TimeInterval
    let unplayedOpacity: Double
    let appliesTimingEffects: Bool

    var animatableData: Double {
        get { playbackTime }
        set { playbackTime = newValue }
    }

    func draw(
        layout: Text.Layout,
        in context: inout GraphicsContext
    ) {
        for line in layout {
            for run in line {
                guard appliesTimingEffects,
                      let timing =
                        run[WatchLyricTimingTextAttribute.self],
                      !timing.isWhitespace else {
                    context.draw(run)
                    continue
                }

                var unplayedContext = context
                unplayedContext.opacity = min(
                    max(unplayedOpacity, 0),
                    1
                )
                unplayedContext.draw(run)
                drawPlayed(
                    run,
                    progress: playedProgress(for: timing),
                    in: &context
                )
            }
        }
    }

    private func drawPlayed(
        _ run: Text.Layout.Run,
        progress: Double,
        in context: inout GraphicsContext
    ) {
        guard progress > 0 else { return }
        guard progress < 1 else {
            context.draw(run)
            return
        }

        let bounds = run.typographicBounds.rect
        guard bounds.width > 0, bounds.height > 0 else { return }
        let frontX = run.layoutDirection == .rightToLeft
            ? bounds.maxX - bounds.width * CGFloat(progress)
            : bounds.minX + bounds.width * CGFloat(progress)
        let featherWidth = max(
            bounds.width * 0.7,
            2
        )
        let startPoint: CGPoint
        let endPoint: CGPoint
        let gradient: Gradient
        if run.layoutDirection == .rightToLeft {
            startPoint = CGPoint(
                x: frontX - featherWidth,
                y: bounds.midY
            )
            endPoint = CGPoint(x: frontX, y: bounds.midY)
            gradient = Gradient(colors: [.clear, .white])
        } else {
            startPoint = CGPoint(x: frontX, y: bounds.midY)
            endPoint = CGPoint(
                x: frontX + featherWidth,
                y: bounds.midY
            )
            gradient = Gradient(colors: [.white, .clear])
        }

        var playedContext = context
        playedContext.clipToLayer { maskContext in
            maskContext.fill(
                Path(bounds),
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
        }
        playedContext.draw(run)
    }

    private func playedProgress(
        for timing: WatchLyricTimingTextAttribute
    ) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }
        let duration = timing.endTime - timing.startTime
        guard duration > 0 else { return 1 }
        return min(
            max(
                (playbackTime - timing.startTime) / duration,
                0
            ),
            1
        )
    }
}

@available(watchOS 11.0, *)
private extension WatchLyricTextRenderer {
    struct TimedRun {
        let timing: WatchLyricTimingTextAttribute
        let bounds: CGRect
        let layoutDirection: LayoutDirection
    }

    struct LineRevealMask {
        let frontX: CGFloat
        let featherWidth: CGFloat
        let gradient: Gradient
        let layoutDirection: LayoutDirection
    }

    struct RunVisualState {
        let liftProgress: Double
        let expansionScale: CGFloat
        let emphasis: WatchLyricLongToneEmphasis.State
        let unplayedBlurRadius: CGFloat
        let glowStrength: Double
    }

    enum Metrics {
        static let displayPaddingMultiplier: CGFloat = 6
        static let unplayedBlurLeadDuration: TimeInterval = 2.4
        static let minimumUnplayedBlurFraction = 0.12
        static let glowAttackProgress = 0.24
        static let minimumGlowStrength = 0.82
        static let ordinaryGlowStrengthMultiplier = 0.55
        static let liftContinuationDuration: TimeInterval = 0.32
        static let outerGlowRadiusMultiplier: CGFloat = 1
        static let outerGlowOpacityMultiplier = 0.55
        static let innerGlowRadiusMultiplier: CGFloat = 0.35
        static let highlightGradientStopCount = 8
        static let minimumRevealFeatherWidth: CGFloat = 2
        static let highlightAttackDuration: TimeInterval = 0.3
        static let highlightReleaseDuration: TimeInterval = 0.16
        static let highlightAttackContribution = 0.82
        static let highlightContinuousContribution = 0.08
        static let highlightReleaseContribution = 0.1
    }
}
