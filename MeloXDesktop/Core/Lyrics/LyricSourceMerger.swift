import Foundation

struct LyricSourceCollection: Sendable {
    var amllTTML: String?
    var netease: NeteaseLyricPayload?
    var qqMusic: QQLyricPayload?
}

enum LyricSourceMerger {
    static func resolve(
        _ sources: LyricSourceCollection,
        preference: LyricSourcePreference = .automatic
    ) -> ResolvedLyrics? {
        switch preference {
        case .automatic:
            return resolveAutomatic(sources)
        case .amll:
            return resolveAMLL(sources) ?? resolvePureMusic(sources)
        case .netease:
            return resolveNetease(sources, requiresTranslationForYRC: false)
                ?? resolvePureMusic(sources)
        case .qqMusic:
            return resolveQQMusic(sources) ?? resolvePureMusic(sources)
        }
    }

    private static func resolveAutomatic(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        if let resolved = resolveAMLL(sources) {
            return resolved
        }

        if let netease = sources.netease,
           let yrc = normalized(netease.yrc),
           normalized(netease.translatedYRC) != nil
            || normalized(netease.translatedLRC) != nil {
            let lines = LyricParser.parse(
                yrc: yrc,
                lrc: netease.lrc ?? "",
                translatedYRC: netease.translatedYRC ?? "",
                translatedLRC: netease.translatedLRC ?? "",
                romanizedYRC: netease.romanizedYRC ?? "",
                romanizedLRC: netease.romanizedLRC ?? ""
            )
            if !lines.isEmpty {
                return ResolvedLyrics(
                    source: .netease,
                    quality: .neteaseVerbatim,
                    lines: lines,
                    isPureMusic: netease.isPureMusic
                )
            }
        }

        if let resolved = resolveQQMusicVerbatim(sources) {
            return resolved
        }

        if let netease = sources.netease,
           let lrc = normalized(netease.lrc) {
            let lines = LyricParser.parse(
                yrc: "",
                lrc: lrc,
                translatedLRC: netease.translatedLRC ?? "",
                romanizedLRC: netease.romanizedLRC ?? ""
            )
            if !lines.isEmpty {
                return ResolvedLyrics(
                    source: .netease,
                    quality: .neteaseLineSynchronized,
                    lines: lines,
                    isPureMusic: netease.isPureMusic
                )
            }
        }

        if let resolved = resolveQQMusicLineSynchronized(sources) {
            return resolved
        }

        return resolvePureMusic(sources)
    }

    private static func resolveAMLL(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        guard let ttml = normalized(sources.amllTTML) else { return nil }
        let lines = TTMLLyricParser.parse(ttml)
        guard !lines.isEmpty else { return nil }
        return ResolvedLyrics(
            source: .amll,
            quality: .amllTTML,
            lines: lines,
            isPureMusic: sources.netease?.isPureMusic == true
        )
    }

    private static func resolveNetease(
        _ sources: LyricSourceCollection,
        requiresTranslationForYRC: Bool
    ) -> ResolvedLyrics? {
        guard let netease = sources.netease else { return nil }

        if let yrc = normalized(netease.yrc),
           !requiresTranslationForYRC
            || normalized(netease.translatedYRC) != nil
            || normalized(netease.translatedLRC) != nil {
            let lines = LyricParser.parse(
                yrc: yrc,
                lrc: netease.lrc ?? "",
                translatedYRC: netease.translatedYRC ?? "",
                translatedLRC: netease.translatedLRC ?? "",
                romanizedYRC: netease.romanizedYRC ?? "",
                romanizedLRC: netease.romanizedLRC ?? ""
            )
            if !lines.isEmpty {
                return ResolvedLyrics(
                    source: .netease,
                    quality: .neteaseVerbatim,
                    lines: lines,
                    isPureMusic: netease.isPureMusic
                )
            }
        }

        if let lrc = normalized(netease.lrc) {
            let lines = LyricParser.parse(
                yrc: "",
                lrc: lrc,
                translatedLRC: netease.translatedLRC ?? "",
                romanizedLRC: netease.romanizedLRC ?? ""
            )
            if !lines.isEmpty {
                return ResolvedLyrics(
                    source: .netease,
                    quality: .neteaseLineSynchronized,
                    lines: lines,
                    isPureMusic: netease.isPureMusic
                )
            }
        }
        return nil
    }

    private static func resolveQQMusic(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        resolveQQMusicVerbatim(sources)
            ?? resolveQQMusicLineSynchronized(sources)
    }

    private static func resolveQQMusicVerbatim(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        guard let qqMusic = sources.qqMusic,
              let qrc = normalized(qqMusic.verbatim) else {
            return nil
        }
        let normalizedQRC = QRCLyricNormalizer.normalize(qrc)
        let normalizedRomanization = qqMusic.romanization.map(
            QRCLyricNormalizer.normalize
        ) ?? ""
        let lines = LyricParser.parse(
            yrc: normalizedQRC,
            lrc: qqMusic.lineSynchronized ?? "",
            translatedLRC: qqMusic.translation ?? "",
            romanizedYRC: normalizedRomanization,
            romanizedLRC: qqMusic.romanization ?? "",
            duetLRC: sources.netease?.lrc
        )
        guard !lines.isEmpty else { return nil }
        return ResolvedLyrics(
            source: .qqMusic,
            quality: .qqMusicVerbatim,
            lines: lines,
            isPureMusic: sources.netease?.isPureMusic == true
        )
    }

    private static func resolveQQMusicLineSynchronized(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        guard let qqMusic = sources.qqMusic,
              let lrc = normalized(qqMusic.lineSynchronized) else {
            return nil
        }
        let lines = LyricParser.parse(
            yrc: "",
            lrc: lrc,
            translatedLRC: qqMusic.translation ?? "",
            romanizedLRC: qqMusic.romanization ?? "",
            duetLRC: sources.netease?.lrc
        )
        guard !lines.isEmpty else { return nil }
        return ResolvedLyrics(
            source: .qqMusic,
            quality: .qqMusicLineSynchronized,
            lines: lines,
            isPureMusic: sources.netease?.isPureMusic == true
        )
    }

    private static func resolvePureMusic(
        _ sources: LyricSourceCollection
    ) -> ResolvedLyrics? {
        guard sources.netease?.isPureMusic == true else { return nil }
        return ResolvedLyrics(
            source: .netease,
            quality: .fallback,
            lines: [
                LyricLine(
                    time: 0,
                    text: L10n.string("ui.lyrics.instrumental")
                )
            ],
            isPureMusic: true
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
