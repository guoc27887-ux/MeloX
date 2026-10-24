import Foundation

enum LyricsLongSyllableDetectionMode:
    String, CaseIterable, Identifiable, Sendable {
    case word
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word:
            L10n.string("ui.settings.lyrics.long_syllable.word")
        case .character:
            L10n.string("ui.settings.lyrics.long_syllable.character")
        }
    }
}
