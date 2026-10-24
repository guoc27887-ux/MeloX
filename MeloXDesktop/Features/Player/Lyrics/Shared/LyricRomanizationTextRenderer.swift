import SwiftUI

/// Draws pronunciation as a lightweight karaoke reveal. Ruby text deliberately
/// omits blur, glow, lift, and scale so only the gray-to-white sweep animates.
struct LyricRomanizationTextRenderer: TextRenderer {
    var playbackTime: TimeInterval
    let unplayedOpacity: Double
    let trailingVisualOverflow: CGFloat
    let appliesTimingEffects: Bool
    var timingEffectsStrength: Double

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(
                playbackTime,
                timingEffectsStrength
            )
        }
        set {
            playbackTime = newValue.first
            timingEffectsStrength = newValue.second
        }
    }

    var displayPadding: EdgeInsets {
        EdgeInsets(
            top: 0,
            leading: 0,
            bottom: 0,
            trailing: max(trailingVisualOverflow, 0)
        )
    }

    func draw(
        layout: Text.Layout,
        in context: inout GraphicsContext
    ) {
        let effectsStrength = effectiveTimingEffectsStrength
        for line in layout {
            for run in line {
                let horizontalOffset =
                    run[LyricRubyPlacementTextAttribute.self]?
                        .horizontalOffset ?? 0
                var runContext = context
                if horizontalOffset != 0 {
                    runContext.translateBy(
                        x: horizontalOffset,
                        y: 0
                    )
                }

                guard effectsStrength > 0,
                      let timing =
                        run[LyricTimingTextAttribute.self],
                      !timing.isWhitespace else {
                    runContext.draw(run)
                    continue
                }

                drawUnplayed(
                    run,
                    effectsStrength: effectsStrength,
                    in: &runContext
                )
                drawPlayed(
                    run,
                    progress: playedProgress(for: timing),
                    in: &runContext
                )
            }
        }
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        effectsStrength: Double,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        let normalizedUnplayedOpacity = min(
            max(unplayedOpacity, 0),
            1
        )
        unplayedContext.opacity =
            1
            - (1 - normalizedUnplayedOpacity) * effectsStrength
        unplayedContext.draw(run)
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
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let frontX: CGFloat
        if run.layoutDirection == .rightToLeft {
            frontX = bounds.maxX
                - bounds.width * CGFloat(progress)
        } else {
            frontX = bounds.minX
                + bounds.width * CGFloat(progress)
        }
        let featherWidth = max(
            bounds.width * Metrics.gradientWidth,
            Metrics.minimumFeatherWidth
        )
        let startPoint: CGPoint
        let endPoint: CGPoint
        let gradient: Gradient

        if run.layoutDirection == .rightToLeft {
            startPoint = CGPoint(
                x: frontX - featherWidth,
                y: bounds.midY
            )
            endPoint = CGPoint(
                x: frontX,
                y: bounds.midY
            )
            gradient = Gradient(colors: [.clear, .white])
        } else {
            startPoint = CGPoint(
                x: frontX,
                y: bounds.midY
            )
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
        for timing: LyricTimingTextAttribute
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

    private var effectiveTimingEffectsStrength: Double {
        guard appliesTimingEffects else { return 0 }
        return min(max(timingEffectsStrength, 0), 1)
    }
}

private extension LyricRomanizationTextRenderer {
    enum Metrics {
        static let gradientWidth: CGFloat = 0.7
        static let minimumFeatherWidth: CGFloat = 2
    }
}
