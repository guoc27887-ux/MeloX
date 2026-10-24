import Foundation
import Observation

enum AutoMixMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case fixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart:
            L10n.string("ui.settings.automix.mode.smart")
        case .fixed:
            L10n.string("ui.settings.automix.mode.fixed")
        }
    }

    var description: String {
        switch self {
        case .smart:
            L10n.string("ui.settings.automix.mode.smart.detail")
        case .fixed:
            L10n.string("ui.settings.automix.mode.fixed.detail")
        }
    }
}

enum AutoMixTransitionBars: Int, CaseIterable, Identifiable, Sendable {
    case four = 4
    case eight = 8
    case sixteen = 16

    var id: Int { rawValue }

    var title: String {
        L10n.format("ui.settings.automix.bars", rawValue)
    }
}

enum AutoMixTailCutBars: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case two = 2
    case four = 4
    case eight = 8

    var id: Int { rawValue }

    var title: String {
        rawValue == 0
            ? L10n.string("ui.settings.automix.tail.play_to_end")
            : L10n.format("ui.settings.automix.tail.cut_bars", rawValue)
    }
}

nonisolated enum AutoMixFadeCurve: String, CaseIterable, Identifiable, Sendable {
    case equalPower
    case smooth
    case linear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equalPower:
            L10n.string("ui.settings.automix.curve.equal_power")
        case .smooth:
            L10n.string("ui.settings.automix.curve.smooth")
        case .linear:
            L10n.string("ui.settings.automix.curve.linear")
        }
    }

    var description: String {
        switch self {
        case .equalPower:
            L10n.string("ui.settings.automix.curve.equal_power.detail")
        case .smooth:
            L10n.string("ui.settings.automix.curve.smooth.detail")
        case .linear:
            L10n.string("ui.settings.automix.curve.linear.detail")
        }
    }
}

enum AutoMixFallbackBehavior: String, CaseIterable, Identifiable, Sendable {
    case crossfade
    case shortCrossfade
    case normal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crossfade:
            L10n.string("ui.settings.automix.fallback.crossfade")
        case .shortCrossfade:
            L10n.string("ui.settings.automix.fallback.short_crossfade")
        case .normal:
            L10n.string("ui.settings.automix.fallback.normal")
        }
    }

    var description: String {
        switch self {
        case .crossfade:
            L10n.string("ui.settings.automix.fallback.crossfade.detail")
        case .shortCrossfade:
            L10n.string("ui.settings.automix.fallback.short_crossfade.detail")
        case .normal:
            L10n.string("ui.settings.automix.fallback.normal.detail")
        }
    }
}

struct AutoMixConfiguration: Equatable, Sendable {
    let mode: AutoMixMode
    let transitionBars: Int
    let tailCutBars: Int
    let fixedDuration: TimeInterval
    let preloadLeadTime: TimeInterval
    let fadeCurve: AutoMixFadeCurve
    let tempoMatchingEnabled: Bool
    let maximumTempoAdjustmentPercent: Double
    let skipsQuietOpening: Bool
    let minimumAnalysisConfidence: Double
    let analyzesStreamingTracks: Bool
    let fallbackBehavior: AutoMixFallbackBehavior
}

@MainActor
@Observable
final class AutoMixPreferences {
    static let defaultMode: AutoMixMode = .smart
    static let defaultTransitionBars: AutoMixTransitionBars = .eight
    static let defaultTailCutBars: AutoMixTailCutBars = .four
    static let defaultFixedDuration = 8.0
    static let fixedDurationRange = 3.0...20.0
    static let defaultPreloadLeadTime = 90.0
    static let preloadLeadTimeRange = 30.0...180.0
    static let defaultFadeCurve: AutoMixFadeCurve = .equalPower
    static let defaultTempoMatchingEnabled = true
    static let defaultMaximumTempoAdjustmentPercent = 5.0
    static let maximumTempoAdjustmentPercentRange = 1.0...8.0
    static let defaultSkipsQuietOpening = true
    static let defaultMinimumAnalysisConfidence = 0.42
    static let minimumAnalysisConfidenceRange = 0.2...0.8
    static let defaultAnalyzesStreamingTracks = true
    static let defaultFallbackBehavior: AutoMixFallbackBehavior = .crossfade

    private enum Key {
        static let mode = "autoMix.mode"
        static let transitionBars = "autoMix.transitionBars"
        static let tailCutBars = "autoMix.tailCutBars"
        static let fixedDuration = "autoMix.fixedDuration"
        static let preloadLeadTime = "autoMix.preloadLeadTime"
        static let fadeCurve = "autoMix.fadeCurve"
        static let tempoMatchingEnabled = "autoMix.tempoMatchingEnabled"
        static let maximumTempoAdjustmentPercent =
            "autoMix.maximumTempoAdjustmentPercent"
        static let skipsQuietOpening = "autoMix.skipsQuietOpening"
        static let minimumAnalysisConfidence =
            "autoMix.minimumAnalysisConfidence"
        static let analyzesStreamingTracks =
            "autoMix.analyzesStreamingTracks"
        static let fallbackBehavior = "autoMix.fallbackBehavior"
    }

    var mode: AutoMixMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    var transitionBars: AutoMixTransitionBars {
        didSet {
            defaults.set(
                transitionBars.rawValue,
                forKey: Key.transitionBars
            )
        }
    }

    var tailCutBars: AutoMixTailCutBars {
        didSet {
            defaults.set(
                tailCutBars.rawValue,
                forKey: Key.tailCutBars
            )
        }
    }

    var fixedDuration: Double {
        didSet {
            let clampedValue =
                Self.fixedDurationRange.clamped(fixedDuration)
            guard clampedValue == fixedDuration else {
                fixedDuration = clampedValue
                return
            }
            defaults.set(fixedDuration, forKey: Key.fixedDuration)
        }
    }

    var preloadLeadTime: Double {
        didSet {
            let clampedValue =
                Self.preloadLeadTimeRange.clamped(preloadLeadTime)
            guard clampedValue == preloadLeadTime else {
                preloadLeadTime = clampedValue
                return
            }
            defaults.set(preloadLeadTime, forKey: Key.preloadLeadTime)
        }
    }

    var fadeCurve: AutoMixFadeCurve {
        didSet {
            defaults.set(fadeCurve.rawValue, forKey: Key.fadeCurve)
        }
    }

    var tempoMatchingEnabled: Bool {
        didSet {
            defaults.set(
                tempoMatchingEnabled,
                forKey: Key.tempoMatchingEnabled
            )
        }
    }

    var maximumTempoAdjustmentPercent: Double {
        didSet {
            let clampedValue =
                Self.maximumTempoAdjustmentPercentRange.clamped(
                    maximumTempoAdjustmentPercent
                )
            guard clampedValue == maximumTempoAdjustmentPercent else {
                maximumTempoAdjustmentPercent = clampedValue
                return
            }
            defaults.set(
                maximumTempoAdjustmentPercent,
                forKey: Key.maximumTempoAdjustmentPercent
            )
        }
    }

    var skipsQuietOpening: Bool {
        didSet {
            defaults.set(
                skipsQuietOpening,
                forKey: Key.skipsQuietOpening
            )
        }
    }

    var minimumAnalysisConfidence: Double {
        didSet {
            let clampedValue =
                Self.minimumAnalysisConfidenceRange.clamped(
                    minimumAnalysisConfidence
                )
            guard clampedValue == minimumAnalysisConfidence else {
                minimumAnalysisConfidence = clampedValue
                return
            }
            defaults.set(
                minimumAnalysisConfidence,
                forKey: Key.minimumAnalysisConfidence
            )
        }
    }

    var analyzesStreamingTracks: Bool {
        didSet {
            defaults.set(
                analyzesStreamingTracks,
                forKey: Key.analyzesStreamingTracks
            )
        }
    }

    var fallbackBehavior: AutoMixFallbackBehavior {
        didSet {
            defaults.set(
                fallbackBehavior.rawValue,
                forKey: Key.fallbackBehavior
            )
        }
    }

    var configuration: AutoMixConfiguration {
        AutoMixConfiguration(
            mode: mode,
            transitionBars: transitionBars.rawValue,
            tailCutBars: tailCutBars.rawValue,
            fixedDuration: fixedDuration,
            preloadLeadTime: preloadLeadTime,
            fadeCurve: fadeCurve,
            tempoMatchingEnabled: tempoMatchingEnabled,
            maximumTempoAdjustmentPercent:
                maximumTempoAdjustmentPercent,
            skipsQuietOpening: skipsQuietOpening,
            minimumAnalysisConfidence: minimumAnalysisConfidence,
            analyzesStreamingTracks: analyzesStreamingTracks,
            fallbackBehavior: fallbackBehavior
        )
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AutoMixMode(
            rawValue: defaults.string(forKey: Key.mode) ?? ""
        ) ?? Self.defaultMode
        transitionBars = AutoMixTransitionBars(
            rawValue: defaults.integer(forKey: Key.transitionBars)
        ) ?? Self.defaultTransitionBars
        if defaults.object(forKey: Key.tailCutBars) != nil {
            tailCutBars = AutoMixTailCutBars(
                rawValue: defaults.integer(
                    forKey: Key.tailCutBars
                )
            ) ?? Self.defaultTailCutBars
        } else {
            tailCutBars = Self.defaultTailCutBars
        }
        fixedDuration = Self.fixedDurationRange.clamped(
            defaults.object(forKey: Key.fixedDuration) as? Double
                ?? Self.defaultFixedDuration
        )
        preloadLeadTime = Self.preloadLeadTimeRange.clamped(
            defaults.object(forKey: Key.preloadLeadTime) as? Double
                ?? Self.defaultPreloadLeadTime
        )
        fadeCurve = AutoMixFadeCurve(
            rawValue: defaults.string(forKey: Key.fadeCurve) ?? ""
        ) ?? Self.defaultFadeCurve
        tempoMatchingEnabled = defaults.object(
            forKey: Key.tempoMatchingEnabled
        ) as? Bool ?? Self.defaultTempoMatchingEnabled
        maximumTempoAdjustmentPercent =
            Self.maximumTempoAdjustmentPercentRange.clamped(
                defaults.object(
                    forKey: Key.maximumTempoAdjustmentPercent
                ) as? Double
                    ?? Self.defaultMaximumTempoAdjustmentPercent
            )
        skipsQuietOpening = defaults.object(
            forKey: Key.skipsQuietOpening
        ) as? Bool ?? Self.defaultSkipsQuietOpening
        minimumAnalysisConfidence =
            Self.minimumAnalysisConfidenceRange.clamped(
                defaults.object(
                    forKey: Key.minimumAnalysisConfidence
                ) as? Double
                    ?? Self.defaultMinimumAnalysisConfidence
            )
        analyzesStreamingTracks = defaults.object(
            forKey: Key.analyzesStreamingTracks
        ) as? Bool ?? Self.defaultAnalyzesStreamingTracks
        fallbackBehavior = AutoMixFallbackBehavior(
            rawValue: defaults.string(forKey: Key.fallbackBehavior) ?? ""
        ) ?? Self.defaultFallbackBehavior
    }

    func reset() {
        mode = Self.defaultMode
        transitionBars = Self.defaultTransitionBars
        tailCutBars = Self.defaultTailCutBars
        fixedDuration = Self.defaultFixedDuration
        preloadLeadTime = Self.defaultPreloadLeadTime
        fadeCurve = Self.defaultFadeCurve
        tempoMatchingEnabled = Self.defaultTempoMatchingEnabled
        maximumTempoAdjustmentPercent =
            Self.defaultMaximumTempoAdjustmentPercent
        skipsQuietOpening = Self.defaultSkipsQuietOpening
        minimumAnalysisConfidence =
            Self.defaultMinimumAnalysisConfidence
        analyzesStreamingTracks =
            Self.defaultAnalyzesStreamingTracks
        fallbackBehavior = Self.defaultFallbackBehavior
    }
}

private extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double {
        Swift.min(
            Swift.max(value, lowerBound),
            upperBound
        )
    }
}
