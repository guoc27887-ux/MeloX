import Foundation

struct QQMusicTrackMatch: Codable, Hashable, Sendable {
    let id: Int64
    let title: String
    let album: String
    let artist: String
    let durationSeconds: Int
}

actor QQMusicLyricMatchStore {
    private let fileURL: URL
    private var matches: [String: QQMusicTrackMatch]?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    func match(for neteaseSongID: Int) -> QQMusicTrackMatch? {
        loadIfNeeded()
        return matches?[String(neteaseSongID)]
    }

    func set(_ match: QQMusicTrackMatch, for neteaseSongID: Int) {
        loadIfNeeded()
        matches?[String(neteaseSongID)] = match
        persist()
    }

    func remove(for neteaseSongID: Int) {
        loadIfNeeded()
        matches?[String(neteaseSongID)] = nil
        persist()
    }

    private func loadIfNeeded() {
        guard matches == nil else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(
                  [String: QQMusicTrackMatch].self,
                  from: data
              ) else {
            matches = [:]
            return
        }
        matches = stored
    }

    private func persist() {
        guard let matches,
              let data = try? JSONEncoder().encode(matches) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let root = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("MeloX", isDirectory: true)
            .appendingPathComponent("Lyrics", isDirectory: true)
            .appendingPathComponent("qq-matches.json")
    }
}
