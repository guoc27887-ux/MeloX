import Foundation
import Observation

@MainActor
@Observable
final class AppleMusicLyricsPreferences {
    private enum Key {
        static let motionPreset =
            "melox.desktop.lyrics.appleMusic.motionPreset"
    }

    var motionPreset: AppleMusicLyricsMotionPreset {
        didSet {
            defaults.set(motionPreset.rawValue, forKey: Key.motionPreset)
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
        ) ?? .appleMusic26
    }

    func reset() {
        motionPreset = .appleMusic26
    }
}
