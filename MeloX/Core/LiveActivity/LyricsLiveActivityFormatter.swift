import Foundation

struct LyricsLiveActivityText: Equatable {
    let title: String
    let subtitle: String
    let compact: String
}

enum LyricsLiveActivityFormatter {
    static func text(
        songTitle: String,
        songArtist: String,
        currentLyric: String?,
        preferences: LyricsLiveActivityPreferences
    ) -> LyricsLiveActivityText {
        let lyric = nonempty(currentLyric) ?? songTitle
        let replacements = L10n.lyricFormatReplacements(
            lyric: lyric,
            title: songTitle,
            artist: songArtist
        )

        return LyricsLiveActivityText(
            title: render(
                preferences.titleFormat,
                replacements: replacements,
                fallback: lyric
            ),
            subtitle: render(
                preferences.subtitleFormat,
                replacements: replacements,
                fallback: [songTitle, songArtist]
                    .filter { !$0.isEmpty }
                    .joined(
                        separator: L10n.string(
                            "ui.common.metadata_separator"
                        )
                    )
            ),
            compact: render(
                preferences.compactFormat,
                replacements: replacements,
                fallback: lyric
            )
        )
    }

    private static func render(
        _ format: String,
        replacements: [String: String],
        fallback: String
    ) -> String {
        let rendered = replacements.reduce(format) {
            result,
            replacement in
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
