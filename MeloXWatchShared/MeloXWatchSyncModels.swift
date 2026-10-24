import Foundation

nonisolated struct MeloXWatchAccountSnapshot: Codable, Equatable {
    var cookie: String
    var nickname: String?
    var avatarURLString: String?
    var updatedAt: Date

    static let empty = MeloXWatchAccountSnapshot(
        cookie: "",
        nickname: nil,
        avatarURLString: nil,
        updatedAt: .distantPast
    )
}

nonisolated struct MeloXWatchLyricsPreferences: Codable, Equatable {
    var showsTranslation: Bool
    var showsRomanization: Bool
    var usesWordByWordHighlight: Bool
    var usesGlow: Bool
    var advanceTime: TimeInterval
    var currentLineScale: Double
    var blurIntensity: Double
    var distanceBlurScale: Double
    var glowIntensity: Double
    var focusCascadeDelay: TimeInterval
    var focusCascadeDelayIncrease: TimeInterval
    var focusCascadeFollowingDelay: TimeInterval
    var focusCascadeDuration: TimeInterval
    var focusCascadeBounceEnabled: Bool
    var focusCascadeBounce: Double
    var focusCascadeBounceGradient: Double
    var focusScaleBounceEnabled: Bool
    var focusScaleBounce: Double
    var focusScaleBounceDuration: TimeInterval
    var dimAmount: Double
    var focusPosition: Double
    var usesUniformDimmingWhileBrowsing: Bool
    var romanizationFontScale: Double
    var romanizationOpacity: Double
    var liftModeRawValue: String
    var longToneDetectionModeRawValue: String
    var longToneDurationThreshold: TimeInterval
    var longToneExpansionAmount: Double

    static let standard = MeloXWatchLyricsPreferences(
        showsTranslation: true,
        showsRomanization: false,
        usesWordByWordHighlight: true,
        usesGlow: true,
        advanceTime: 0.2,
        currentLineScale: 1.02,
        blurIntensity: 0.8,
        distanceBlurScale: 1.05,
        glowIntensity: 1,
        focusCascadeDelay: 0.021,
        focusCascadeDelayIncrease: 0.005,
        focusCascadeFollowingDelay: 0.048,
        focusCascadeDuration: 0.74,
        focusCascadeBounceEnabled: true,
        focusCascadeBounce: 0.26,
        focusCascadeBounceGradient: 0.85,
        focusScaleBounceEnabled: true,
        focusScaleBounce: 0.32,
        focusScaleBounceDuration: 0.58,
        dimAmount: 1,
        focusPosition: 0.25,
        usesUniformDimmingWhileBrowsing: true,
        romanizationFontScale: 0.65,
        romanizationOpacity: 0.9,
        liftModeRawValue: "character",
        longToneDetectionModeRawValue: "character",
        longToneDurationThreshold: 0.95,
        longToneExpansionAmount: 0.05
    )
}

nonisolated struct MeloXWatchSnapshot: Codable, Equatable {
    var account: MeloXWatchAccountSnapshot
    var updatedAt: Date

    static let empty = MeloXWatchSnapshot(
        account: .empty,
        updatedAt: .distantPast
    )
}

nonisolated struct MeloXWatchEnvelope: Codable {
    nonisolated enum Kind: String, Codable {
        case snapshot
        case account
        case requestSnapshot
    }

    static let messageKey = "melox.watch.envelope"

    let kind: Kind
    var snapshot: MeloXWatchSnapshot?
    var account: MeloXWatchAccountSnapshot?

    static func message(snapshot: MeloXWatchSnapshot) -> [String: Any] {
        message(
            MeloXWatchEnvelope(
                kind: .snapshot,
                snapshot: snapshot,
                account: nil
            )
        )
    }

    static func message(account: MeloXWatchAccountSnapshot) -> [String: Any] {
        message(
            MeloXWatchEnvelope(
                kind: .account,
                snapshot: nil,
                account: account
            )
        )
    }

    static let snapshotRequestMessage = message(
        MeloXWatchEnvelope(
            kind: .requestSnapshot,
            snapshot: nil,
            account: nil
        )
    )

    static func decode(_ message: [String: Any]) -> MeloXWatchEnvelope? {
        guard let data = message[messageKey] as? Data else { return nil }
        return try? JSONDecoder().decode(MeloXWatchEnvelope.self, from: data)
    }

    private static func message(_ envelope: MeloXWatchEnvelope) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(envelope) else { return [:] }
        return [messageKey: data]
    }
}
