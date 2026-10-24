import SwiftUI

@MainActor
enum DesktopLyricsAnimations {
    static func focusEffectAnimation(
        settings: AppSettings,
        highlightedID: LyricLine.ID?,
        lyrics: [LyricLine],
        reduceMotion: Bool
    ) -> Animation? {
        guard !reduceMotion else { return nil }
        if let profile = settings.appleMusicLyricsMotionProfile {
            return .timingCurve(
                profile.focusBlurTransitionControlPoint1X,
                profile.focusBlurTransitionControlPoint1Y,
                profile.focusBlurTransitionControlPoint2X,
                profile.focusBlurTransitionControlPoint2Y,
                duration: profile.focusBlurTransitionDuration
            )
        }
        let movementDuration =
            LyricPlaybackTimeline.focusAnimationDuration(
                for: highlightedID,
                in: lyrics
            )
        return .easeInOut(duration: max(movementDuration, 0.2))
    }

    static func focusScaleDuration(
        settings: AppSettings,
        highlightedID: LyricLine.ID?,
        lyrics: [LyricLine]
    ) -> TimeInterval {
        if settings.lyricsFocusScaleBounceEnabled {
            return min(
                max(
                    settings.lyricsFocusScaleBounceDuration,
                    AppSettings
                        .lyricsFocusScaleBounceDurationRange.lowerBound
                ),
                AppSettings.lyricsFocusScaleBounceDurationRange.upperBound
            )
        }
        return min(
            max(
                LyricPlaybackTimeline.focusAnimationDuration(
                    for: highlightedID,
                    in: lyrics
                ),
                0.28
            ),
            0.42
        )
    }

    static func focusScaleAnimation(
        settings: AppSettings,
        highlightedID: LyricLine.ID?,
        lyrics: [LyricLine],
        reduceMotion: Bool,
        isFocused: Bool
    ) -> Animation? {
        guard !reduceMotion else { return nil }

        if let spring = settings.appleMusicLyricsMotionProfile?
            .lineChangeSpring {
            return .interpolatingSpring(
                mass: spring.mass,
                stiffness: spring.stiffness,
                damping: spring.damping,
                initialVelocity: 0
            )
        }

        let duration = focusScaleDuration(
            settings: settings,
            highlightedID: highlightedID,
            lyrics: lyrics
        )
        guard isFocused,
              settings.lyricsFocusScaleBounceEnabled else {
            return .smooth(duration: duration)
        }

        let bounce = min(
            max(
                settings.lyricsFocusScaleBounce,
                AppSettings.lyricsFocusScaleBounceRange.lowerBound
            ),
            AppSettings.lyricsFocusScaleBounceRange.upperBound
        )
        return .spring(
            duration: duration,
            bounce: bounce,
            blendDuration: min(max(duration * 0.22, 0.06), 0.14)
        )
    }
}
