import Foundation

/// 第三方音源音质档位。
///
/// 改写自 Beans Music（XIaodou0416/Beans-Music，MIT 协议）Models.swift 的
/// ThirdPartyAudioQuality：档位、别名归一、降级链与各平台支持表均与 Beans 一致。
enum ThirdPartyAudioQuality: String, CaseIterable, Identifiable, Sendable {
    case kb128 = "128k"
    case kb320 = "320k"
    case flac = "flac"
    case flac24bit = "flac24bit"
    case hires = "hires"
    case atmos = "atmos"
    case atmosPlus = "atmos_plus"
    case master = "master"

    var id: String { rawValue }

    /// 兼容第三方脚本常见的音质别名（例如 24bit / lossless）。
    init?(sourceValue: String) {
        let normalized = sourceValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch normalized {
        case "128", "128k", "low", "standard": self = .kb128
        case "320", "320k", "high", "exhigh": self = .kb320
        case "flac", "lossless": self = .flac
        case "24bit", "flac24", "flac24bit", "hires24": self = .flac24bit
        case "hires", "highres", "high-resolution": self = .hires
        case "atmos", "dolby": self = .atmos
        case "atmosplus", "atmos_plus", "dolbyplus": self = .atmosPlus
        case "master", "masterquality": self = .master
        default: return nil
        }
    }

    var displayName: String {
        L10n.string("ui.unblock.quality.\(rawValue)")
    }

    /// 从高往低自动滑的降级链：请求不到高档时依次尝试更低档。
    var fallbackChain: [ThirdPartyAudioQuality] {
        switch self {
        case .kb128:
            return [.kb128]
        case .kb320:
            return [.kb320, .kb128]
        case .flac:
            return [.flac, .kb320, .kb128]
        case .flac24bit:
            return [.flac24bit, .flac, .kb320, .kb128]
        case .hires:
            return [.hires, .flac24bit, .flac, .kb320, .kb128]
        case .atmos:
            return [.atmos, .hires, .flac24bit, .flac, .kb320, .kb128]
        case .atmosPlus:
            return [.atmosPlus, .atmos, .hires, .flac24bit, .flac, .kb320, .kb128]
        case .master:
            return [.master, .atmosPlus, .atmos, .hires, .flac24bit, .flac, .kb320, .kb128]
        }
    }

    /// 各平台代号支持的音质档位（wy 网易云 / tx QQ / kg 酷狗 / kw 酷我 / mg 咪咕）。
    static func supported(providerCode: String) -> [ThirdPartyAudioQuality] {
        switch providerCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "kw", "mg":
            return [.kb128, .kb320, .flac, .flac24bit, .hires]
        case "kg":
            return [.kb128, .kb320, .flac, .flac24bit, .hires, .atmos, .master]
        case "tx":
            return allCases
        case "wy":
            return [.kb128, .kb320, .flac, .flac24bit, .hires, .atmos, .master]
        case "git":
            return [.kb128, .kb320, .flac]
        default:
            return allCases
        }
    }
}
