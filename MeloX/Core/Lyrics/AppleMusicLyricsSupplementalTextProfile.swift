import Foundation

/// Reconstructed layout constants for Apple Music's transliteration and
/// translation layers. These values describe the iOS 26.6 implementation;
/// they are not public Apple API.
nonisolated struct AppleMusicLyricsSupplementalTextProfile: Equatable, Sendable {
    let transliterationSpacing: Double
    let transliterationMinimumWordSpacing: Double
    let translationSpacing: Double
    let translationBottomPadding: Double
    let hiddenVerticalOffset: Double

    static let iOS26_6 = Self(
        transliterationSpacing: 5,
        transliterationMinimumWordSpacing: 5,
        translationSpacing: 7,
        translationBottomPadding: 4,
        hiddenVerticalOffset: -20
    )
}
