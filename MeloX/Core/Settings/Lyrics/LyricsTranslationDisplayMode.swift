import Foundation

enum LyricsTranslationDisplayMode: String, CaseIterable, Identifiable {
    case focusedLine
    case allLines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusedLine:
            L10n.string("ui.settings.lyrics.auxiliary.focused_line")
        case .allLines:
            L10n.string("ui.settings.lyrics.auxiliary.all_lines")
        }
    }
}
