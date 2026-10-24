import Foundation
import Observation

@MainActor
@Observable
final class AppleMusicLyricsPreferences {
    private enum Key {
        static let motionPreset =
            "melox.lyrics.appleMusic.motionPreset"
    }

    private enum Default {
        static let motionPreset: AppleMusicLyricsMotionPreset =
            .appleMusic26
    }

    var motionPreset: AppleMusicLyricsMotionPreset {
        didSet {
            defaults.set(
                motionPreset.rawValue,
                forKey: Key.motionPreset
            )
        }
    }

    var usesAppleMusic26Motion: Bool {
        motionPreset == .appleMusic26
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        motionPreset = AppleMusicLyricsMotionPreset(
            rawValue: defaults.string(forKey: Key.motionPreset) ?? ""
        ) ?? Default.motionPreset
    }

    func reset() {
        motionPreset = Default.motionPreset
    }
}
