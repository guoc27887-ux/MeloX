import Foundation

enum PlayerBackgroundStyle: String, CaseIterable, Identifiable {
    case appleMusicBackdrop
    case flowingLight
    case blurredArtwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusicBackdrop:
            L10n.string("ui.settings.player_background.apple_music")
        case .flowingLight:
            L10n.string("ui.settings.player_background.flowing_light")
        case .blurredArtwork:
            L10n.string("ui.settings.player_background.blurred_artwork")
        }
    }
}
