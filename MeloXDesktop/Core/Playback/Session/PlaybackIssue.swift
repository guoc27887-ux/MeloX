import Foundation

struct PlaybackIssue: Identifiable, Sendable {
    let id = UUID()
    let message: String

    init(song: Song, error: Error) {
        if let apiError = error as? APIError,
           case .noPlayableSource = apiError {
            message = L10n.format("ui.error.playback.unavailable", song.name)
            return
        }

        if let playbackError = error as? AudioPlaybackError,
           case .itemFailed = playbackError {
            message = L10n.format("ui.error.playback.source_load_failed", song.name)
            return
        }

        message = L10n.format("ui.error.playback.failed", song.name, error.localizedDescription)
    }
}
