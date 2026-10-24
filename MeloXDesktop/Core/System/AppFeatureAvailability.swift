import Foundation

enum AppFeatureAvailability {
    /// The desktop target owns a sandboxed Application Support directory and
    /// exposes the complete offline library in every build configuration.
    static let downloads = true
}
