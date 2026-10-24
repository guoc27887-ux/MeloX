import Foundation
import Observation

nonisolated enum LyricsInterludePresentationMode:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case hidden
    case preciseTiming
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden:
            L10n.string("ui.common.off")
        case .preciseTiming:
            L10n.string("ui.settings.lyrics.interlude.precise")
        case .automatic:
            L10n.string("ui.settings.lyrics.interlude.automatic")
        }
    }

    var description: String {
        switch self {
        case .hidden:
            L10n.string("ui.settings.lyrics.interlude.hidden.detail")
        case .preciseTiming:
            L10n.string("ui.settings.lyrics.interlude.precise.detail")
        case .automatic:
            L10n.string("ui.settings.lyrics.interlude.automatic.detail")
        }
    }

}

@MainActor
@Observable
final class LyricsInterludePreferences {
    static let inferredGapDurationRange = 3.0...12.0
    static let defaultMode: LyricsInterludePresentationMode = .automatic
    static let defaultMinimumInferredGapDuration = 4.0

    private enum Key {
        static let mode = "melox.lyrics.interlude.mode"
        static let minimumInferredGapDuration =
            "melox.lyrics.interlude.minimumInferredGapDuration"
        static let legacyEnabled = "lyricsInterludeCountdownEnabled"
    }

    var mode: LyricsInterludePresentationMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    var minimumInferredGapDuration: TimeInterval {
        didSet {
            defaults.set(
                minimumInferredGapDuration,
                forKey: Key.minimumInferredGapDuration
            )
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedMode = defaults.string(forKey: Key.mode),
           let mode = LyricsInterludePresentationMode(
               rawValue: storedMode
           ) {
            self.mode = mode
        } else if let legacyEnabled = defaults.object(
            forKey: Key.legacyEnabled
        ) as? Bool {
            mode = legacyEnabled ? .automatic : .hidden
        } else {
            mode = Self.defaultMode
        }

        let storedMinimum = defaults.object(
            forKey: Key.minimumInferredGapDuration
        ) as? Double ?? Self.defaultMinimumInferredGapDuration
        minimumInferredGapDuration = min(
            max(storedMinimum, Self.inferredGapDurationRange.lowerBound),
            Self.inferredGapDurationRange.upperBound
        )
    }

    func reset() {
        mode = Self.defaultMode
        minimumInferredGapDuration =
            Self.defaultMinimumInferredGapDuration
    }
}
