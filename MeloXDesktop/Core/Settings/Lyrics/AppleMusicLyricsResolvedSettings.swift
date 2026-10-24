import Foundation

@MainActor
extension AppSettings {
    var appleMusicLyricsMotionProfile: AppleMusicLyricsMotionProfile? {
        appleMusicLyrics.usesAppleMusic26Motion ? .macOS26_6 : nil
    }

    var effectiveAppleMusicLyricsFontSize: Double {
        appleMusicLyricsMotionProfile == nil
            ? lyricsFontSize
            : Double(
                AppleMusicLyricsTypographyProfile.macOS26_6
                    .primaryFontSize(for: 384)
            )
    }

    var effectiveAppleMusicLyricsFontWeight: LyricsFontWeight {
        appleMusicLyricsMotionProfile == nil ? lyricsFontWeight : .bold
    }

    var effectiveAppleMusicLyricsLineSpacing: Double {
        appleMusicLyricsMotionProfile?.lineSpacing ?? lyricsLineSpacing
    }

    var effectiveAppleMusicLyricsParagraphSpacing: Double {
        appleMusicLyricsMotionProfile?.paragraphSpacing
            ?? lyricsLineSpacing
    }

    var effectiveAppleMusicLyricsCurrentLineScale: Double {
        appleMusicLyricsMotionProfile == nil ? lyricsCurrentLineScale : 1
    }
}
