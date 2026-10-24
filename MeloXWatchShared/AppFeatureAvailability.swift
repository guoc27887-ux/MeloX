import Foundation

enum AppFeatureAvailability {
    /// App Store Connect builds use the `azki.moye.MeloX` bundle identifier
    /// family. Legacy/self-signed builds use `moye.MeloX` and keep downloads.
    static let downloads: Bool = {
        #if DEBUG
            true
        #else
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                return false
            }
            return !bundleIdentifier.hasPrefix("azki.moye.MeloX")
        #endif
    }()
}
