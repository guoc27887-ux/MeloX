import Foundation

enum FloatingLyricsTextEffect: String, CaseIterable, Identifiable {
    case none
    case shadow
    case glow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: L10n.string("ui.desktop.floating_lyrics.effect.none")
        case .shadow: L10n.string("ui.desktop.floating_lyrics.effect.shadow")
        case .glow: L10n.string("ui.desktop.floating_lyrics.effect.glow")
        }
    }
}
