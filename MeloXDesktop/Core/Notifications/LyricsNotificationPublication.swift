import Foundation

struct LyricsNotificationPublicationKey: Equatable {
    let songID: Int
    let lyricID: LyricLine.ID?
    let usesTrackFallback: Bool
}

struct LyricsNotificationPublication {
    let key: LyricsNotificationPublicationKey
    let text: LyricsNotificationText
    let artworkURL: URL?
    let isPreview: Bool
}

@MainActor
enum LyricsNotificationPublicationFactory {
    static func current(
        song: Song,
        lyrics: [LyricLine],
        playbackTime: TimeInterval,
        preferences: LyricsNotificationPreferences
    ) -> LyricsNotificationPublication? {
        let context = lyricContext(
            lyrics: lyrics,
            playbackTime: playbackTime
        )
        guard context.current != nil
                || preferences
                    .showsTrackInfoWhenLyricsUnavailable else {
            return nil
        }
        return publication(
            song: song,
            currentLyric: context.current,
            nextLyric: context.next,
            preferences: preferences,
            isPreview: false
        )
    }

    static func preview(
        song: Song?,
        lyrics: [LyricLine],
        playbackTime: TimeInterval,
        preferences: LyricsNotificationPreferences
    ) -> LyricsNotificationPublication {
        let resolvedSong = song ?? Song(
            id: -1,
            name: L10n.string("ui.lyrics.notification.preview.song"),
            artists: [
                Artist(
                    id: -1,
                    name: L10n.string("ui.lyrics.notification.preview.artist")
                )
            ]
        )
        let context = lyricContext(
            lyrics: lyrics,
            playbackTime: playbackTime
        )
        let currentLyric = context.current ?? LyricLine(
            time: 0,
            text: L10n.string("ui.lyrics.notification.preview.current"),
            translation: L10n.string("ui.lyrics.notification.preview.translation")
        )
        let nextLyric = context.next ?? LyricLine(
            time: 4,
            text: L10n.string("ui.lyrics.notification.preview.next")
        )
        return publication(
            song: resolvedSong,
            currentLyric: currentLyric,
            nextLyric: nextLyric,
            preferences: preferences,
            isPreview: true
        )
    }

    private static func publication(
        song: Song,
        currentLyric: LyricLine?,
        nextLyric: LyricLine?,
        preferences: LyricsNotificationPreferences,
        isPreview: Bool
    ) -> LyricsNotificationPublication {
        let displaySettings =
            LyricsNotificationDisplaySettings(
                titleFormat: preferences.titleFormat,
                showsSubtitle:
                    preferences.showsSubtitle,
                subtitleFormat:
                    preferences.subtitleFormat,
                supplementaryContent:
                    preferences.supplementaryContent
            )
        let text = LyricsNotificationFormatter.text(
            songTitle: song.name,
            songArtist: song.artistText,
            currentLyric: currentLyric?.text,
            translation: currentLyric?.translation,
            nextLyric: nextLyric?.text,
            settings: displaySettings
        )
        return LyricsNotificationPublication(
            key: LyricsNotificationPublicationKey(
                songID: song.id,
                lyricID: currentLyric?.id,
                usesTrackFallback: currentLyric == nil
            ),
            text: text,
            artworkURL: preferences.showsArtwork
                ? song.album?.artworkURL
                : nil,
            isPreview: isPreview
        )
    }

    private static func lyricContext(
        lyrics: [LyricLine],
        playbackTime: TimeInterval
    ) -> (current: LyricLine?, next: LyricLine?) {
        let position = LyricPlaybackTimeline.position(
            at: playbackTime,
            in: lyrics
        )
        let currentIndex = position.highlightedLyricID.flatMap {
            lyricID in
            lyrics.firstIndex(where: { $0.id == lyricID })
        }
        let current = currentIndex.map { lyrics[$0] }
        let next: LyricLine? = if let currentIndex {
            lyrics.indices.contains(currentIndex + 1)
                ? lyrics[currentIndex + 1]
                : nil
        } else {
            lyrics.first
        }
        return (current, next)
    }
}
