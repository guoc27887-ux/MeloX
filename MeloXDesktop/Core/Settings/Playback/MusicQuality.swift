import Foundation

nonisolated enum MusicQuality:
    String,
    CaseIterable,
    Identifiable,
    Codable,
    Sendable
{
    // Keep the original raw values so existing preferences and download records
    // continue to decode after switching playback to the level-based v1 API.
    case standard = "128000"
    case high = "320000"
    case lossless = "flac"
    case hiResolution = "hires"
    case highDefinitionSurround = "jyeffect"
    case immersiveSurround = "sky"
    case ultraClearMaster = "jymaster"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: L10n.string("ui.settings.audio_quality.standard")
        case .high: L10n.string("ui.settings.audio_quality.high")
        case .lossless: L10n.string("ui.settings.audio_quality.lossless")
        case .hiResolution: L10n.string("ui.settings.audio_quality.hi_res")
        case .highDefinitionSurround: L10n.string("ui.settings.audio_quality.hd_surround")
        case .immersiveSurround: L10n.string("ui.settings.audio_quality.immersive_surround")
        case .ultraClearMaster: L10n.string("ui.settings.audio_quality.master")
        }
    }

    var apiLevel: String {
        switch self {
        case .standard: "standard"
        case .high: "exhigh"
        case .lossless: "lossless"
        case .hiResolution: "hires"
        case .highDefinitionSurround: "jyeffect"
        case .immersiveSurround: "sky"
        case .ultraClearMaster: "jymaster"
        }
    }

    init?(apiLevel: String) {
        guard let quality = Self.allCases.first(where: {
            $0.apiLevel == apiLevel
        }) else {
            return nil
        }
        self = quality
    }

    var requiresImmersiveType: Bool {
        self == .immersiveSurround
    }

    var prefersExtendedBuffering: Bool {
        switch self {
        case .standard, .high:
            false
        case .lossless, .hiResolution,
             .highDefinitionSurround, .immersiveSurround,
             .ultraClearMaster:
            true
        }
    }

    var playbackFallbacks: [MusicQuality] {
        switch self {
        case .standard:
            [.standard]
        case .high:
            [.high, .standard]
        case .lossless:
            [.lossless, .high, .standard]
        case .hiResolution:
            [.hiResolution, .lossless, .high, .standard]
        case .highDefinitionSurround:
            [.highDefinitionSurround, .lossless, .high, .standard]
        case .immersiveSurround:
            [
                .immersiveSurround,
                .highDefinitionSurround,
                .lossless,
                .high,
                .standard,
            ]
        case .ultraClearMaster:
            [.ultraClearMaster, .hiResolution, .lossless, .high, .standard]
        }
    }

    func playbackCandidates(
        for availability: SongAudioAvailability
    ) -> [MusicQuality] {
        playbackFallbacks.filter {
            availability.supports(apiLevel: $0.apiLevel) != false
        }
    }
}
