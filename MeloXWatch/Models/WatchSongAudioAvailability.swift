import Foundation

nonisolated struct WatchSongAudioResource: Codable, Hashable {
    let bitrate: Int?
    let fileID: Int64?
    let size: Int64?
    let volumeDelta: Double?
    let sampleRate: Int?

    enum CodingKeys: String, CodingKey {
        case bitrate = "br"
        case fileID = "fid"
        case size
        case volumeDelta = "vd"
        case sampleRate = "sr"
    }
}

nonisolated struct WatchSongAudioAvailability: Codable, Hashable {
    static let unknown = WatchSongAudioAvailability()

    let standard: WatchSongAudioResource?
    let high: WatchSongAudioResource?
    let lossless: WatchSongAudioResource?
    let hiResolution: WatchSongAudioResource?
    let highDefinitionSurround: WatchSongAudioResource?
    let immersiveSurround: WatchSongAudioResource?
    let ultraClearMaster: WatchSongAudioResource?
    let isKnown: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case standard = "l"
        case high = "h"
        case lossless = "sq"
        case hiResolution = "hr"
        case highDefinitionSurround = "je"
        case immersiveSurround = "sk"
        case ultraClearMaster = "jm"
        case isKnown = "_meloxAudioAvailabilityKnown"
    }

    private init() {
        standard = nil
        high = nil
        lossless = nil
        hiResolution = nil
        highDefinitionSurround = nil
        immersiveSurround = nil
        ultraClearMaster = nil
        isKnown = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        standard = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .standard
        )
        high = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .high
        )
        lossless = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .lossless
        )
        hiResolution = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .hiResolution
        )
        highDefinitionSurround = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .highDefinitionSurround
        )
        immersiveSurround = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .immersiveSurround
        )
        ultraClearMaster = try container.decodeIfPresent(
            WatchSongAudioResource.self,
            forKey: .ultraClearMaster
        )
        isKnown = try container.decodeIfPresent(
            Bool.self,
            forKey: .isKnown
        ) ?? CodingKeys.allCases
            .filter { $0 != .isKnown }
            .contains { container.contains($0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(standard, forKey: .standard)
        try container.encodeIfPresent(high, forKey: .high)
        try container.encodeIfPresent(lossless, forKey: .lossless)
        try container.encodeIfPresent(hiResolution, forKey: .hiResolution)
        try container.encodeIfPresent(
            highDefinitionSurround,
            forKey: .highDefinitionSurround
        )
        try container.encodeIfPresent(
            immersiveSurround,
            forKey: .immersiveSurround
        )
        try container.encodeIfPresent(
            ultraClearMaster,
            forKey: .ultraClearMaster
        )
        if isKnown {
            try container.encode(true, forKey: .isKnown)
        }
    }

    func supports(apiLevel: String) -> Bool? {
        guard isKnown else { return nil }
        return switch apiLevel {
        case "standard":
            standard != nil
        case "exhigh":
            high != nil
        case "lossless":
            lossless != nil
        case "hires":
            hiResolution != nil
        case "jyeffect":
            highDefinitionSurround != nil
        case "sky":
            immersiveSurround != nil
        case "jymaster":
            ultraClearMaster != nil
        default:
            false
        }
    }
}
