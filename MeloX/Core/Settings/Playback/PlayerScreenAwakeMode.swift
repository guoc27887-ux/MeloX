import Foundation

enum PlayerScreenAwakeMode: String, CaseIterable, Identifiable {
    case disabled
    case player
    case lyrics
    case hiddenLyricsInterface

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled:
            L10n.string("ui.common.off")
        case .player:
            L10n.string("ui.settings.screen_awake.player")
        case .lyrics:
            L10n.string("ui.settings.screen_awake.lyrics")
        case .hiddenLyricsInterface:
            L10n.string("ui.settings.screen_awake.hidden_lyrics_ui")
        }
    }
}
