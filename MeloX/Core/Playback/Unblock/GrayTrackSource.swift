import Foundation

/// 灰色歌曲解锁可用的第三方音源（与 kumone 的音源列表一致）。
enum GrayTrackSource: String, CaseIterable, Hashable, Sendable {
    case pyncmd
    case kugou
    case kuwo

    var displayName: String {
        switch self {
        case .pyncmd:
            return L10n.string("ui.unblock.source.pyncmd")
        case .kugou:
            return L10n.string("ui.unblock.source.kugou")
        case .kuwo:
            return L10n.string("ui.unblock.source.kuwo")
        }
    }
}
