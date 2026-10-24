import Foundation

struct WatchArtist: Codable, Hashable, Identifiable {
    let id: Int
    let name: String

    init(id: Int = 0, name: String) {
        self.id = id
        self.name = name
    }
}

struct WatchAlbum: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let artworkURLString: String?

    var artworkURL: URL? {
        WatchArtworkURL.make(from: artworkURLString, dimension: 400)
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case artworkURLString = "picUrl"
    }
}

struct WatchSong: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let artists: [WatchArtist]
    let album: WatchAlbum?
    let durationMS: Int
    let audioAvailability: WatchSongAudioAvailability

    var artistText: String {
        L10n.joined(
            artists.map(\.name),
            separatorKey: "ui.common.artist_separator"
        )
    }

    var duration: TimeInterval {
        TimeInterval(durationMS) / 1_000
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ar, artists, al, album, dt, duration
    }

    init(
        id: Int,
        name: String,
        artists: [WatchArtist],
        album: WatchAlbum?,
        durationMS: Int,
        audioAvailability: WatchSongAudioAvailability = .unknown
    ) {
        self.id = id
        self.name = name
        self.artists = artists
        self.album = album
        self.durationMS = durationMS
        self.audioAvailability = audioAvailability
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? L10n.string("ui.metadata.unknown_song")
        artists = try container.decodeIfPresent(
            [WatchArtist].self,
            forKey: .ar
        ) ?? container.decodeIfPresent(
            [WatchArtist].self,
            forKey: .artists
        ) ?? []
        album = try container.decodeIfPresent(
            WatchAlbum.self,
            forKey: .al
        ) ?? container.decodeIfPresent(
            WatchAlbum.self,
            forKey: .album
        )
        durationMS = try container.decodeIfPresent(
            Int.self,
            forKey: .dt
        ) ?? container.decodeIfPresent(
            Int.self,
            forKey: .duration
        ) ?? 0
        audioAvailability = try WatchSongAudioAvailability(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(artists, forKey: .artists)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encode(durationMS, forKey: .duration)
        try audioAvailability.encode(to: encoder)
    }
}

struct WatchPlaylist: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let artworkURLString: String?
    let trackCount: Int
    var tracks: [WatchSong]
    let trackIDs: [WatchTrackReference]

    var artworkURL: URL? {
        WatchArtworkURL.make(from: artworkURLString, dimension: 300)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, trackCount, tracks
        case artworkURLString = "coverImgUrl"
        case alternateArtworkURLString = "picUrl"
        case trackIDs = "trackIds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? L10n.string("ui.metadata.unknown_playlist")
        artworkURLString = try container.decodeIfPresent(
            String.self,
            forKey: .artworkURLString
        ) ?? container.decodeIfPresent(
            String.self,
            forKey: .alternateArtworkURLString
        )
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        tracks = try container.decodeIfPresent([WatchSong].self, forKey: .tracks) ?? []
        trackIDs = try container.decodeIfPresent(
            [WatchTrackReference].self,
            forKey: .trackIDs
        ) ?? []
    }
}

struct WatchTrackReference: Codable, Hashable {
    let id: Int
}

struct WatchAccountProfile: Codable, Equatable {
    let userID: Int
    let nickname: String
    let avatarURLString: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
    }
}

nonisolated struct WatchLyricSyllable:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var id: String {
        "\(startTime)-\(endTime)-\(text)"
    }
}

nonisolated enum WatchBackgroundVocalsPosition:
    String,
    Codable,
    Hashable,
    Sendable
{
    case beforePrimary
    case afterPrimary
}

nonisolated struct WatchBackgroundVocal:
    Codable,
    Hashable,
    Sendable
{
    let time: TimeInterval
    let duration: TimeInterval?
    let text: String
    let syllables: [WatchLyricSyllable]
    let translation: String?
    let position: WatchBackgroundVocalsPosition

    func lyricLine() -> WatchLyricLine {
        WatchLyricLine(
            time: time,
            duration: duration,
            text: text,
            syllables: syllables,
            romanization: nil,
            romanizationSyllables: [],
            translation: translation,
            backgroundVocal: nil,
            isSecondaryVocal: true
        )
    }
}

nonisolated struct WatchLyricLine:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let time: TimeInterval
    let duration: TimeInterval?
    let text: String
    let syllables: [WatchLyricSyllable]
    var romanization: String?
    var romanizationSyllables: [WatchLyricSyllable]
    var translation: String?
    var backgroundVocal: WatchBackgroundVocal? = nil
    var isSecondaryVocal: Bool? = nil

    var id: String {
        "\(time)-\(text)"
    }

    var effectiveSyllables: [WatchLyricSyllable] {
        guard syllables.isEmpty,
              let duration,
              duration > 0 else {
            return syllables
        }
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }
        let step = duration / Double(characters.count)
        return characters.enumerated().map { index, character in
            let start = time + Double(index) * step
            return WatchLyricSyllable(
                text: String(character),
                startTime: start,
                endTime: start + step
            )
        }
    }
}

enum WatchRepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: L10n.string("ui.player.repeat.off")
        case .all: L10n.string("ui.player.repeat.all")
        case .one: L10n.string("ui.player.repeat.one")
        }
    }

    var controlTitle: String {
        switch self {
        case .off: L10n.string("ui.watch.repeat.control")
        case .all: L10n.string("ui.watch.repeat.list")
        case .one: L10n.string("ui.watch.repeat.song")
        }
    }

    var systemImage: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .off: L10n.string("ui.watch.repeat.off.hint")
        case .all: L10n.string("ui.watch.repeat.all.hint")
        case .one: L10n.string("ui.watch.repeat.one.hint")
        }
    }
}

enum WatchPagePhase<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

enum WatchArtworkURL {
    static func make(from source: String?, dimension: Int) -> URL? {
        guard var source = source?.trimmingCharacters(in: .whitespacesAndNewlines),
              !source.isEmpty else {
            return nil
        }
        if source.hasPrefix("//") {
            source = "https:\(source)"
        }
        guard var components = URLComponents(string: source) else { return nil }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }
        components.queryItems = [
            URLQueryItem(name: "param", value: "\(dimension)y\(dimension)")
        ]
        return components.url
    }
}
