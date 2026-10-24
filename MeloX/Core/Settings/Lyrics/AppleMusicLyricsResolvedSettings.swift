import Foundation

@MainActor
extension AppSettings {
    var appleMusicLyricsMotionProfile:
        AppleMusicLyricsMotionProfile? {
        appleMusicLyrics.usesAppleMusic26Motion
            ? .iOS26_6
            : nil
    }

    var appleMusicLyricsTypographyProfile:
        AppleMusicLyricsTypographyProfile? {
        appleMusicLyrics.usesAppleMusic26Motion
            ? .iOS26_6
            : nil
    }

    var effectiveAppleMusicLyricsPrimaryFontSize: Double {
        appleMusicLyricsTypographyProfile?.primaryFontSize
            ?? lyricsFontSize
    }

    var effectiveAppleMusicLyricsLineSpacing: Double {
        appleMusicLyricsMotionProfile?.lineSpacing
            ?? lyricsLineSpacing
    }

    var effectiveAppleMusicLyricsCurrentLineScale: Double {
        guard let profile = appleMusicLyricsMotionProfile else {
            return lyricsCurrentLineScale
        }
        // Apple's selected line stays at identity. The profile's 0.98 value
        // belongs to deselected lines and is applied by the row renderer.
        _ = profile
        return 1
    }

    var effectiveAppleMusicLyricsCascadeDelay: TimeInterval {
        appleMusicLyricsMotionProfile?.cascadeDelay
            ?? lyricsFocusCascadeDelay
    }

    var effectiveAppleMusicLyricsCascadeDelayIncrease:
        TimeInterval {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusCascadeDelayIncrease
            : 0
    }

    var effectiveAppleMusicLyricsFollowingDelay: TimeInterval {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusCascadeFollowingDelay
            : 0
    }

    var effectiveAppleMusicLyricsCatchUpRatio: Double {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusCascadeCatchUpRatio
            : 1
    }

    var effectiveAppleMusicLyricsChaseSpeedGradient: Double {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusCascadeChaseSpeedGradient
            : 1
    }

    var effectiveAppleMusicLyricsCascadeDuration: TimeInterval {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusCascadeDuration
            : 0
    }

    var effectiveAppleMusicLyricsSnapThreshold: TimeInterval {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusSnapThreshold
            : 0
    }

    var effectiveAppleMusicLyricsFocusColorLeadTime: TimeInterval {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFocusColorLeadTime
            : 0
    }
}
