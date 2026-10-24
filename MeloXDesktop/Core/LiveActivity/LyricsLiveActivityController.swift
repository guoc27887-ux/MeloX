import Foundation

enum LyricsLiveActivityCompactTextSize:
    String,
    Codable,
    Hashable,
    CaseIterable,
    Identifiable
{
    case small
    case standard
    case large

    var id: Self { self }

    var pointSize: Double {
        switch self {
        case .small: 10
        case .standard: 12
        case .large: 14
        }
    }
}

struct LyricsLiveActivityPresentation: Codable, Hashable {
    let showsArtwork: Bool
    let showsNextLyric: Bool
    let showsProgress: Bool
    let scrollsCompactText: Bool
    let compactTextSize: LyricsLiveActivityCompactTextSize
    let scrollSpeed: Double
    let scrollPause: TimeInterval
}

struct LyricsLiveActivitySnapshot: Equatable {
    let songID: Int
    let title: String
    let subtitle: String
    let compactText: String
    let compactScrollDistance: Double
    let nextLyric: String?
    let artworkURL: URL?
    let presentation: LyricsLiveActivityPresentation
    let isPlaying: Bool
    let playbackPosition: TimeInterval
    let duration: TimeInterval
    let staleDate: Date?
}

/// Keeps the playback contract shared with the phone implementation while the
/// desktop app exposes lyrics through native windows instead of ActivityKit.
@MainActor
final class LyricsLiveActivityController {
    private(set) var latestSnapshot: LyricsLiveActivitySnapshot?

    func synchronize(with snapshot: LyricsLiveActivitySnapshot?) {
        latestSnapshot = snapshot
    }
}
