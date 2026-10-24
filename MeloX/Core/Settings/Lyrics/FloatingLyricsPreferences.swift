import Foundation
import Observation

@MainActor
@Observable
final class FloatingLyricsPreferences {
    static let fontScaleRange = 0.75...1.35
    static let defaultFontScale = 1.0

    private enum Key {
        static let showsTranslation = "floatingLyrics.showsTranslation"
        static let showsNextLine = "floatingLyrics.showsNextLine"
        static let fontScale = "floatingLyrics.fontScale"
    }

    var showsTranslation: Bool {
        didSet {
            defaults.set(showsTranslation, forKey: Key.showsTranslation)
        }
    }

    var showsNextLine: Bool {
        didSet {
            defaults.set(showsNextLine, forKey: Key.showsNextLine)
        }
    }

    var fontScale: Double {
        didSet {
            defaults.set(fontScale, forKey: Key.fontScale)
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsTranslation = defaults.object(
            forKey: Key.showsTranslation
        ) as? Bool ?? true
        showsNextLine = defaults.object(
            forKey: Key.showsNextLine
        ) as? Bool ?? true

        let storedFontScale = defaults.object(
            forKey: Key.fontScale
        ) as? Double ?? Self.defaultFontScale
        fontScale = min(
            max(storedFontScale, Self.fontScaleRange.lowerBound),
            Self.fontScaleRange.upperBound
        )
    }

    func reset() {
        showsTranslation = true
        showsNextLine = true
        fontScale = Self.defaultFontScale
    }
}
