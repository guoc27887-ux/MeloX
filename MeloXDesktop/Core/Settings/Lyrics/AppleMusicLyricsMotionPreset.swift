import Foundation

enum AppleMusicLyricsMotionPreset: String, CaseIterable, Identifiable {
    case appleMusic26
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic26: L10n.string("ui.settings.lyrics.motion_preset.apple_music_26")
        case .custom: L10n.string("ui.common.custom")
        }
    }

    var description: String {
        switch self {
        case .appleMusic26:
            L10n.string("ui.settings.lyrics.motion_preset.apple_music_26.desktop_detail")
        case .custom:
            L10n.string("ui.settings.lyrics.motion_preset.custom.detail")
        }
    }
}
