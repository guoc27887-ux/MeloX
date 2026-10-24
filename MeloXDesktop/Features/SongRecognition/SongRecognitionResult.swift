import Foundation

struct SongRecognitionResult: Identifiable {
    var id: Int { song.id }

    var song: Song
    let startTimeMilliseconds: Int?

    var playbackPosition: TimeInterval {
        TimeInterval(max(startTimeMilliseconds ?? 0, 0)) / 1_000
    }
}
