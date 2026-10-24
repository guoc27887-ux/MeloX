import Foundation

enum PlayerBackgroundRenderQuality: String, CaseIterable, Identifiable {
    case automatic
    case high
    case standard
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            L10n.string("ui.desktop.render_quality.automatic")
        case .high:
            L10n.string("ui.desktop.render_quality.high")
        case .standard:
            L10n.string("ui.desktop.render_quality.standard")
        case .low:
            L10n.string("ui.desktop.render_quality.low")
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            L10n.string("ui.desktop.render_quality.automatic.detail")
        case .high:
            L10n.string("ui.desktop.render_quality.high.detail")
        case .standard:
            L10n.string("ui.desktop.render_quality.standard.detail")
        case .low:
            L10n.string("ui.desktop.render_quality.low.detail")
        }
    }
}
