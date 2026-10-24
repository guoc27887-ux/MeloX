import Foundation

struct NowPlayingLyricsDisplaySettings {
    let isEnabled: Bool
    let titleFormat: String
    let subtitleFormat: String
}

struct NowPlayingLyricsMetadata: Equatable {
    let title: String
    let subtitle: String
}

enum NowPlayingLyricsFormatter {
    static func metadata(
        songTitle: String,
        songArtist: String,
        currentLyric: String?,
        settings: NowPlayingLyricsDisplaySettings
    ) -> NowPlayingLyricsMetadata {
        guard settings.isEnabled else {
            return NowPlayingLyricsMetadata(
                title: songTitle,
                subtitle: songArtist
            )
        }

        let lyric = nonempty(currentLyric) ?? songTitle
        let replacements = L10n.lyricFormatReplacements(
            lyric: lyric,
            title: songTitle,
            artist: songArtist
        )
        return NowPlayingLyricsMetadata(
            title: render(
                settings.titleFormat,
                replacements: replacements,
                fallback: songTitle
            ),
            subtitle: render(
                settings.subtitleFormat,
                replacements: replacements,
                fallback: songArtist
            )
        )
    }

    private static func render(
        _ format: String,
        replacements: [String: String],
        fallback: String
    ) -> String {
        let rendered = replacements.reduce(format) { result, replacement in
            result.replacingOccurrences(
                of: replacement.key,
                with: replacement.value
            )
        }
        return nonempty(rendered) ?? fallback
    }

    private static func nonempty(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }
}
