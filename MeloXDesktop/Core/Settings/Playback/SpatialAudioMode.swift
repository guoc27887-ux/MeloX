import Foundation

enum SpatialAudioMode: String, CaseIterable, Identifiable {
    case automatic
    case multichannelOnly
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            L10n.string("ui.desktop.spatial_audio.automatic")
        case .multichannelOnly:
            L10n.string("ui.desktop.spatial_audio.multichannel_only")
        case .disabled:
            L10n.string("ui.common.off")
        }
    }

    var description: String {
        switch self {
        case .automatic:
            L10n.string("ui.desktop.spatial_audio.automatic.description")
        case .multichannelOnly:
            L10n.string("ui.desktop.spatial_audio.multichannel_only.description")
        case .disabled:
            L10n.string("ui.desktop.spatial_audio.disabled.description")
        }
    }
}
