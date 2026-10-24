import Foundation

enum WatchPreferenceKey {
    static let streamingQuality = "melox.watch.streamingQuality"
    static let autoPlaySelection = "melox.watch.autoPlaySelection"
    static let previousButtonBehavior = "melox.watch.previousButtonBehavior"
    static let restoresLastSession = "melox.watch.restoresLastSession"
    static let resumesAfterInterruption = "melox.watch.resumesAfterInterruption"
    static let volume = "melox.watch.volume"

    static let showsTranslation = "melox.watch.showsTranslation"
    static let showsRomanization = "melox.watch.showsRomanization"
    static let wordByWord = "melox.watch.wordByWord"
    static let lyricGlow = "melox.watch.lyricGlow"
    static let lyricGlowIntensity = "melox.watch.lyricGlowIntensity"
    static let lyricAdvanceTime = "melox.watch.lyricAdvanceTime"
    static let lyricBlurIntensity = "melox.watch.lyricBlurIntensity"
    static let lyricDistanceBlurScale = "melox.watch.lyricDistanceBlurScale"
    static let lyricCurrentLineScale = "melox.watch.lyricCurrentLineScale"
    static let lyricHighRefreshRate = "melox.watch.lyricHighRefreshRate"
    static let lyricDimAmount = "melox.watch.lyricDimAmount"
    static let lyricFocusPosition = "melox.watch.lyricFocusPosition"
    static let lyricUniformBrowsingDimming =
        "melox.watch.lyricUniformBrowsingDimming"
    static let lyricRomanizationFontScale =
        "melox.watch.lyricRomanizationFontScale"
    static let lyricRomanizationOpacity =
        "melox.watch.lyricRomanizationOpacity"
    static let lyricLiftMode = "melox.watch.lyricLiftMode"
    static let lyricLongToneDetectionMode =
        "melox.watch.lyricLongToneDetectionMode"
    static let lyricLongToneDurationThreshold =
        "melox.watch.lyricLongToneDurationThreshold"
    static let lyricLongToneExpansionAmount =
        "melox.watch.lyricLongToneExpansionAmount"

    static let shrinksPausedArtwork = "melox.watch.shrinksPausedArtwork"
    static let showsArtist = "melox.watch.showsArtist"
    static let playerBackgroundBlur = "melox.watch.playerBackgroundBlur"
    static let playerBackgroundDim = "melox.watch.playerBackgroundDim"
    static let playerBackgroundSaturation =
        "melox.watch.playerBackgroundSaturation"
}

nonisolated enum WatchStreamingQuality:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case standard
    case high
    case lossless
    case hiResolution
    case highDefinitionSurround
    case immersiveSurround
    case ultraClearMaster

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

    var playbackFallbacks: [WatchStreamingQuality] {
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
        for availability: WatchSongAudioAvailability
    ) -> [WatchStreamingQuality] {
        playbackFallbacks.filter {
            availability.supports(apiLevel: $0.apiLevel) != false
        }
    }
}

enum WatchPreviousButtonBehavior: String, CaseIterable, Identifiable {
    case restartAfterFiveSeconds
    case alwaysPrevious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restartAfterFiveSeconds: L10n.string("ui.watch.playback.previous.restart")
        case .alwaysPrevious: L10n.string("ui.watch.playback.previous.always")
        }
    }
}

enum WatchLyricsRefreshRate: String, CaseIterable, Identifiable {
    case smooth
    case powerSaving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smooth: L10n.string("ui.watch.lyrics.refresh.smooth")
        case .powerSaving: L10n.string("ui.watch.lyrics.refresh.power_saving")
        }
    }

    var minimumInterval: TimeInterval {
        switch self {
        case .smooth: 1.0 / 60.0
        case .powerSaving: 1.0 / 30.0
        }
    }
}

enum WatchLyricTimingMode:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case word
    case character

    var id: String { rawValue }

    var liftTitle: String {
        switch self {
        case .word: L10n.string("ui.settings.lyrics.lift.word")
        case .character: L10n.string("ui.settings.lyrics.lift.character")
        }
    }

    var detectionTitle: String {
        switch self {
        case .word: L10n.string("ui.settings.lyrics.long_syllable.word")
        case .character: L10n.string("ui.settings.lyrics.long_syllable.character")
        }
    }
}

enum WatchPreferenceDefaults {
    static func register() {
        UserDefaults.standard.register(
            defaults: [
                WatchPreferenceKey.streamingQuality:
                    WatchStreamingQuality.high.rawValue,
                WatchPreferenceKey.autoPlaySelection: true,
                WatchPreferenceKey.previousButtonBehavior:
                    WatchPreviousButtonBehavior.restartAfterFiveSeconds.rawValue,
                WatchPreferenceKey.restoresLastSession: true,
                WatchPreferenceKey.resumesAfterInterruption: true,
                WatchPreferenceKey.volume: 1.0,
                WatchPreferenceKey.showsTranslation: true,
                WatchPreferenceKey.showsRomanization: false,
                WatchPreferenceKey.wordByWord: true,
                WatchPreferenceKey.lyricGlow: true,
                WatchPreferenceKey.lyricGlowIntensity: 1.0,
                WatchPreferenceKey.lyricAdvanceTime: 0.2,
                WatchPreferenceKey.lyricBlurIntensity: 0.8,
                WatchPreferenceKey.lyricDistanceBlurScale: 1.05,
                WatchPreferenceKey.lyricCurrentLineScale: 1.02,
                WatchPreferenceKey.lyricHighRefreshRate:
                    WatchLyricsRefreshRate.smooth.rawValue,
                WatchPreferenceKey.lyricDimAmount: 1.0,
                WatchPreferenceKey.lyricFocusPosition: 0.25,
                WatchPreferenceKey.lyricUniformBrowsingDimming: true,
                WatchPreferenceKey.lyricRomanizationFontScale: 0.65,
                WatchPreferenceKey.lyricRomanizationOpacity: 0.9,
                WatchPreferenceKey.lyricLiftMode:
                    WatchLyricTimingMode.character.rawValue,
                WatchPreferenceKey.lyricLongToneDetectionMode:
                    WatchLyricTimingMode.character.rawValue,
                WatchPreferenceKey.lyricLongToneDurationThreshold: 0.95,
                WatchPreferenceKey.lyricLongToneExpansionAmount: 0.05,
                WatchPreferenceKey.shrinksPausedArtwork: false,
                WatchPreferenceKey.showsArtist: true,
                WatchPreferenceKey.playerBackgroundBlur: 18.0,
                WatchPreferenceKey.playerBackgroundDim: 0.62,
                WatchPreferenceKey.playerBackgroundSaturation: 1.15
            ]
        )
    }
}
