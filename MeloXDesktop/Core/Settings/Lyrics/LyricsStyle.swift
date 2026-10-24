import Foundation

enum LyricsStyle: String, CaseIterable, Identifiable {
    case appleMusic
    case eva
    case textPV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic: L10n.string("ui.settings.lyrics.style.apple_music")
        case .eva: L10n.string("ui.settings.lyrics.style.eva")
        case .textPV: L10n.string("ui.settings.lyrics.style.text_pv")
        }
    }

    var systemImage: String {
        switch self {
        case .appleMusic: "quote.bubble"
        case .eva: "rectangle.split.3x1.fill"
        case .textPV: "textformat.size.larger"
        }
    }

    var description: String {
        switch self {
        case .appleMusic: L10n.string("ui.settings.lyrics.style.apple_music.detail")
        case .eva: L10n.string("ui.settings.lyrics.style.eva.detail")
        case .textPV: L10n.string("ui.settings.lyrics.style.text_pv.detail")
        }
    }

    var usesMonochromePlayerBackground: Bool {
        switch self {
        case .eva, .textPV: true
        case .appleMusic: false
        }
    }
}
