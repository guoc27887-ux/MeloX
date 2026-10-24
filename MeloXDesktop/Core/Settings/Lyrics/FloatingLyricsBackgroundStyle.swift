import Foundation

enum FloatingLyricsBackgroundStyle: String, CaseIterable, Identifiable {
    case transparent
    case material
    case light
    case dark
    case blurredArtwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent: L10n.string("ui.desktop.floating_lyrics.background.transparent")
        case .material: L10n.string("ui.desktop.floating_lyrics.background.material")
        case .light: L10n.string("ui.settings.appearance.option.light")
        case .dark: L10n.string("ui.settings.appearance.option.dark")
        case .blurredArtwork: L10n.string("ui.desktop.floating_lyrics.background.blurred_artwork")
        }
    }

    var usesLightForeground: Bool {
        self == .dark || self == .blurredArtwork
    }
}
