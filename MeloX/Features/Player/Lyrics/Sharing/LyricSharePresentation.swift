import Foundation

struct LyricSharePresentation: Identifiable, Hashable {
    let song: Song
    let lyrics: [LyricLine]
    let initialLyricID: LyricLine.ID

    var id: String {
        "\(song.id)-\(initialLyricID)"
    }
}

struct LyricSharePayload: Identifiable {
    let id = UUID()
    let song: Song
    let lyrics: [LyricLine]

    var songURL: URL {
        NeteaseShareResource.song(song).webURL
    }

    var originalLyricsText: String {
        lyrics
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var subject: String {
        L10n.joined(
            [song.name, song.artistText],
            separatorKey: "ui.common.title_detail_separator"
        )
    }
}
