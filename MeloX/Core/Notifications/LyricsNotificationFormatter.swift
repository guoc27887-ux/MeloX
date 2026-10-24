import Foundation

struct LyricsNotificationText: Equatable, Sendable {
    let title: String
    let subtitle: String
    let body: String
}

struct LyricsNotificationDisplaySettings:
    Equatable,
    Sendable
{
    let titleFormat: String
    let showsSubtitle: Bool
    let subtitleFormat: String
    let supplementaryContent:
        LyricsNotificationSupplementaryContent
}

enum LyricsNotificationFormatter {
    static func text(
        songTitle: String,
        songArtist: String,
        currentLyric: String?,
        translation: String?,
        nextLyric: String?,
        settings: LyricsNotificationDisplaySettings
    ) -> LyricsNotificationText {
        let lyric = nonempty(currentLyric) ?? songTitle
        let replacements = L10n.lyricFormatReplacements(
            lyric: lyric,
            title: songTitle,
            artist: songArtist
        )

        var bodyLines = [lyric]
        if settings.supplementaryContent.includesTranslation,
           let translation = nonempty(translation),
           translation != lyric {
            bodyLines.append(translation)
        }
        if settings.supplementaryContent.includesNextLyric,
           let nextLyric = nonempty(nextLyric),
           nextLyric != lyric {
            bodyLines.append(
                L10n.format("ui.lyrics.notification.next", nextLyric)
            )
        }

        return LyricsNotificationText(
            title: render(
                settings.titleFormat,
                replacements: replacements,
                fallback: songTitle
            ),
            subtitle: settings.showsSubtitle
                ? render(
                    settings.subtitleFormat,
                    replacements: replacements,
                    fallback: songArtist
                )
                : "",
            body: bodyLines.joined(separator: "\n")
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
