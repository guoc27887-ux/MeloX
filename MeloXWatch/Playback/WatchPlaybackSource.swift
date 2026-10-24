import Foundation

nonisolated struct WatchPlaybackSource: Sendable {
    let url: URL
    let quality: WatchStreamingQuality?
}
