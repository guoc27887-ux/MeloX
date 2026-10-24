import Foundation

enum FloatingLyricsTextAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: L10n.string("ui.desktop.floating_lyrics.alignment.leading")
        case .center: L10n.string("ui.desktop.floating_lyrics.alignment.center")
        case .trailing: L10n.string("ui.desktop.floating_lyrics.alignment.trailing")
        }
    }
}
