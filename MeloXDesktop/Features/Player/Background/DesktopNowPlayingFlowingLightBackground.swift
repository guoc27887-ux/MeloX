import SwiftUI

struct DesktopNowPlayingFlowingLightBackground: View {
    @Environment(\.accessibilityDimFlashingLights)
    private var accessibilityDimFlashingLights
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase

    let player: PlayerStore
    let palette: ArtworkFlowingLightPalette
    let beatTimeline: PlaybackBeatTimeline?
    let motionIntensity: Double
    let saturation: Double
    let beatEffectsEnabled: Bool
    let isActive: Bool

    var body: some View {
        let colors = meshColors
        let luminousColor = color(
            from: palette.luminousRGB
        )

        TimelineView(
            .animation(
                minimumInterval: 1.0 / 20.0,
                paused: pausesAnimation
            )
        ) { context in
            let playbackTime = accessibilityReduceMotion
                ? 0
                : player.estimatedProgress(at: context.date)
            let vignettePulse = vignettePulse(
                at: playbackTime
            )

            ZStack {
                MeshGradient(
                    width: ArtworkFlowingLightPalette.gridDimension,
                    height: ArtworkFlowingLightPalette.gridDimension,
                    points: meshPoints(
                        at: playbackTime
                    ),
                    colors: colors
                )
                .saturation(
                    max(saturation, 0)
                )
                .contrast(1.02)
                .scaleEffect(1.03)

                flowingLightFields(
                    at: playbackTime,
                    luminousColor: luminousColor,
                    secondaryColor: colors[5]
                )

                DesktopNowPlayingRhythmicVignette(
                    pulse: vignettePulse
                )
            }
        }
    }

    private var pausesAnimation: Bool {
        accessibilityReduceMotion
            || !isActive
            || isLuminanceReduced
            || scenePhase != .active
            || !player.isPlaying
    }

    private var allowsBeatEffects: Bool {
        beatEffectsEnabled
            && isActive
            && player.isPlaying
            && !accessibilityReduceMotion
            && !accessibilityDimFlashingLights
            && !isLuminanceReduced
            && scenePhase == .active
    }

    private var meshColors: [Color] {
        palette.displayColorsRGB.map(color(from:))
    }

    private func color(
        from rgb: SIMD3<Double>
    ) -> Color {
        Color(
            red: rgb.x,
            green: rgb.y,
            blue: rgb.z
        )
    }

    private func vignettePulse(
        at playbackTime: TimeInterval
    ) -> Double {
        guard allowsBeatEffects,
              let beatTimeline else {
            return 0
        }
        return beatTimeline.vignettePulse(
            at: playbackTime
        )
    }

    private func meshPoints(
        at playbackTime: TimeInterval
    ) -> [SIMD2<Float>] {
        let intensity = min(
            max(motionIntensity, 0),
            1.6
        )
        let travel = min(intensity * 1.25, 1.75)
        let motion = DesktopFlowingLightMotionField(
            songID: player.currentSong?.id ?? 0
        )
        let phase =
            playbackTime
                * (0.40 + intensity * 0.15)

        let topX = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 0
                )
                    * 0.14
                    * travel
        )
        let leftY = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 1
                )
                    * 0.13
                    * travel
        )
        let centerX = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 2
                )
                    * 0.18
                    * travel
        )
        let centerY = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 3
                )
                    * 0.18
                    * travel
        )
        let rightY = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 4
                )
                    * 0.14
                    * travel
        )
        let bottomX = boundedPoint(
            0.5
                + motion.value(
                    at: phase,
                    channel: 5
                )
                    * 0.15
                    * travel
        )

        return [
            SIMD2(0, 0),
            SIMD2(topX, 0),
            SIMD2(1, 0),
            SIMD2(0, leftY),
            SIMD2(centerX, centerY),
            SIMD2(1, rightY),
            SIMD2(0, 1),
            SIMD2(bottomX, 1),
            SIMD2(1, 1),
        ]
    }

    private func boundedPoint(_ value: Double) -> Float {
        Float(min(max(value, 0.16), 0.84))
    }

    private func flowingLightFields(
        at playbackTime: TimeInterval,
        luminousColor: Color,
        secondaryColor: Color
    ) -> some View {
        let intensity = min(
            max(motionIntensity, 0),
            1.6
        )
        let travel = min(intensity * 2, 2.4)
        let motion = DesktopFlowingLightMotionField(
            songID: player.currentSong?.id ?? 0
        )
        let phase =
            playbackTime
                * (0.36 + intensity * 0.12)
        let primaryCenter = unitPoint(
            x:
                0.50
                    + motion.value(
                        at: phase,
                        channel: 6
                    )
                        * 0.30
                        * travel,
            y:
                0.38
                    + motion.value(
                        at: phase,
                        channel: 7
                    )
                        * 0.22
                        * travel
        )
        let secondaryCenter = unitPoint(
            x:
                0.50
                    + motion.value(
                        at: phase,
                        channel: 8
                    )
                        * 0.31
                        * travel,
            y:
                0.62
                    + motion.value(
                        at: phase,
                        channel: 9
                    )
                        * 0.23
                        * travel
        )
        let shadowCenter = unitPoint(
            x:
                0.50
                    + motion.value(
                        at: phase,
                        channel: 10
                    )
                        * 0.34
                        * travel,
            y:
                0.52
                    + motion.value(
                        at: phase,
                        channel: 11
                    )
                        * 0.27
                        * travel
        )
        let breathing =
            1
                + motion.value(
                    at: phase,
                    channel: 12
                ) * 0.10

        return DesktopNowPlayingFlowingLightFields(
            primaryCenter: primaryCenter,
            secondaryCenter: secondaryCenter,
            shadowCenter: shadowCenter,
            luminousColor: luminousColor,
            secondaryColor: secondaryColor,
            expansion: breathing
        )
    }

    private func unitPoint(
        x: Double,
        y: Double
    ) -> UnitPoint {
        UnitPoint(
            x: min(max(x, -0.5), 1.5),
            y: min(max(y, -0.5), 1.5)
        )
    }
}
