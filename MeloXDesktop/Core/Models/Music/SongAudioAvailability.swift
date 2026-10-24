import Foundation

struct SongAudioResource: Codable, Hashable, Sendable {
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

struct SongAudioAvailability: Codable, Hashable, Sendable {
    static let unknown = SongAudioAvailability()

    let standard: SongAudioResource?
    let medium: SongAudioResource?
    let high: SongAudioResource?
    let lossless: SongAudioResource?
    let hiResolution: SongAudioResource?
    let highDefinitionSurround: SongAudioResource?
    let immersiveSurround: SongAudioResource?
    let ultraClearMaster: SongAudioResource?
    let isKnown: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case standard = "l"
        case medium = "m"
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
        medium = nil
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
            SongAudioResource.self,
            forKey: .standard
        )
        medium = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .medium
        )
        high = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .high
        )
        lossless = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .lossless
        )
        hiResolution = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .hiResolution
        )
        highDefinitionSurround = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .highDefinitionSurround
        )
        immersiveSurround = try container.decodeIfPresent(
            SongAudioResource.self,
            forKey: .immersiveSurround
        )
        ultraClearMaster = try container.decodeIfPresent(
            SongAudioResource.self,
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
        try container.encodeIfPresent(medium, forKey: .medium)
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
