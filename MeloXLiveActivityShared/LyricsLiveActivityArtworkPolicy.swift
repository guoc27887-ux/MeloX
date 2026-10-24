enum LyricsLiveActivityArtworkPolicy {
    // ActivityKit limits attributes plus content state to 4 KB.
    // These caps leave room for lyrics and presentation metadata.
    nonisolated static let maximumPixelSize = 72
    nonisolated static let maximumJPEGByteCount = 1_300
    nonisolated static let maximumTextCharacterCount = 48
    nonisolated static let imageScale = 3.0
}
