import Foundation

@MainActor
extension DesktopAppModel {
    var currentLyricsFocusID: LyricLine.ID? {
        let lyricLines = lyrics.lyrics
        guard !lyricLines.isEmpty else { return nil }

        let playbackTime = player.estimatedProgress()
            + settings.effectiveLyricsAdvanceTime(for: lyricLines)
        return LyricPlaybackTimeline.position(
            at: playbackTime,
            in: lyricLines
        ).highlightedLyricID ?? lyricLines.first?.id
    }
}
