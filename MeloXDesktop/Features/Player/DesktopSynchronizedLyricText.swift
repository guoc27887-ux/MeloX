import SwiftUI

/// A native SwiftUI karaoke treatment for the currently focused lyric.
/// The text keeps SwiftUI's normal wrapping and accessibility behavior while
/// its timed syllables brighten as playback crosses them.
struct DesktopSynchronizedLyricText: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.lyricsRenderingIsActive)
    private var lyricsRenderingIsActive

    let line: LyricLine
    let nextLineTime: TimeInterval?
    let isPlaybackLine: Bool
    let font: Font
    let color: Color

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval:
                    model.settings.lyricsRefreshRate.minimumInterval,
                paused: !model.player.isPlaying
                    || !lyricsRenderingIsActive
            )
        ) { context in
            synchronizedText(
                at: model.player.estimatedProgress(at: context.date)
                    + model.settings.lyricsAdvanceTime
            )
            .font(font)
            .shadow(
                color: glowColor,
                radius: model.settings.lyricsGlowEnabled ? 7 : 0
            )
        }
    }

    private var glowColor: Color {
        color.opacity(0.18 * model.settings.lyricsGlowIntensity)
    }

    private func synchronizedText(at playbackTime: TimeInterval) -> Text {
        let syllables = displayedSyllables
        guard isPlaybackLine,
              model.settings.lyricsWordByWord,
              !syllables.isEmpty else {
            return Text(line.text).foregroundColor(color)
        }

        return syllables.reduce(Text("")) { text, syllable in
            text + Text(syllable.text)
                .foregroundColor(
                    color.opacity(opacity(for: syllable, at: playbackTime))
                )
        }
    }

    private var displayedSyllables: [LyricSyllable] {
        if !line.syllables.isEmpty {
            return line.syllables
        }
        guard model.settings.lyricsPseudoWordByWord else { return [] }
        if !line.makePseudoSyllables().isEmpty {
            return line.makePseudoSyllables()
        }
        guard let nextLineTime else { return [] }

        let characters = Array(line.text)
        let duration = max(nextLineTime - line.time, 0.2)
        guard !characters.isEmpty else { return [] }
        let unitDuration = duration / Double(characters.count)
        return characters.enumerated().map { index, character in
            let startTime = line.time + Double(index) * unitDuration
            return LyricSyllable(
                text: String(character),
                startTime: startTime,
                endTime: startTime + unitDuration
            )
        }
    }

    private func opacity(
        for syllable: LyricSyllable,
        at playbackTime: TimeInterval
    ) -> Double {
        if playbackTime >= syllable.endTime {
            return 1
        }
        if playbackTime <= syllable.startTime {
            return 0.64
        }
        let duration = max(syllable.endTime - syllable.startTime, 0.01)
        let progress = min(
            max((playbackTime - syllable.startTime) / duration, 0),
            1
        )
        return 0.76 + progress * 0.24
    }
}
