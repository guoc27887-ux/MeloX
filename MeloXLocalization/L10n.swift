import Foundation

nonisolated enum L10n {
    private final class LanguageState: @unchecked Sendable {
        private let lock = NSLock()
        private var language = AppLanguage.selected

        var current: AppLanguage {
            lock.lock()
            defer { lock.unlock() }
            return language
        }

        func activate(_ language: AppLanguage) {
            lock.lock()
            self.language = language
            lock.unlock()
        }
    }

    private static let languageState = LanguageState()

    private static let supportedLocales = [
        Locale(identifier: "en"),
        Locale(identifier: "zh-Hans"),
    ]

    private static let englishBundle = localizedBundle(named: "en")
    private static let simplifiedChineseBundle = localizedBundle(named: "zh-Hans")

    static var locale: Locale {
        languageState.current.locale
    }

    /// Keeps imperative and model-generated strings on the same language as
    /// SwiftUI's locale environment. Call this before publishing a language
    /// preference change so the following view update cannot read stale text.
    static func activate(_ language: AppLanguage) {
        languageState.activate(language)
    }

    static func string(
        _ key: String,
        comment: StaticString? = nil
    ) -> String {
        string(key, locale: locale, comment: comment)
    }

    static func string(
        _ key: String,
        locale: Locale,
        comment: StaticString? = nil
    ) -> String {
        _ = comment
        return bundle(for: locale).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func values(_ key: String) -> [String] {
        var seen = Set<String>()
        return supportedLocales.compactMap { locale in
            let value = string(key, locale: locale)
            return seen.insert(value).inserted ? value : nil
        }
    }

    static func keywords(_ key: String) -> [String] {
        string(key)
            .split(separator: "|")
            .map(String.init)
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key),
            locale: locale,
            arguments: arguments
        )
    }

    static func byteCount(_ value: Int64) -> String {
        value.formatted(
            .byteCount(style: .file)
                .locale(locale)
        )
    }

    static func integer(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    static func percent(
        _ ratio: Double,
        fractionLength: Int = 0
    ) -> String {
        ratio.formatted(
            .percent
                .precision(.fractionLength(fractionLength))
                .locale(locale)
        )
    }

    static func percentagePoints(
        _ value: Double,
        fractionLength: Int = 0
    ) -> String {
        percent(value / 100, fractionLength: fractionLength)
    }

    static func list(_ values: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: values)
            ?? values.joined(separator: ", ")
    }

    static func joined(
        _ values: [String],
        separatorKey: String
    ) -> String {
        values.joined(separator: string(separatorKey))
    }

    static func lyricFormatReplacements(
        lyric: String,
        title: String,
        artist: String
    ) -> [String: String] {
        var replacements: [String: String] = [:]
        for token in values("ui.lyrics.format.token.lyrics") {
            replacements[token] = lyric
        }
        for token in values("ui.lyrics.format.token.title") {
            replacements[token] = title
        }
        for token in values("ui.lyrics.format.token.artist") {
            replacements[token] = artist
        }
        return replacements
    }

    private static func bundle(for locale: Locale) -> Bundle {
        locale.language.languageCode?.identifier == "zh"
            ? simplifiedChineseBundle
            : englishBundle
    }

    private static func localizedBundle(named localization: String) -> Bundle {
        guard
            let path = Bundle.main.path(
                forResource: localization,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}
