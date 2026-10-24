import Foundation

struct PersonalizedResponse: Decodable {
    let result: [Playlist]
}

struct NewAlbumsResponse: Decodable {
    let albums: [Album]
}

struct ToplistsResponse: Decodable {
    let list: [Playlist]
}

struct TopPlaylistsResponse: Decodable {
    let playlists: [Playlist]
    let more: Bool?
}

struct PlaylistDetailResponse: Decodable {
    let playlist: Playlist
}

struct SongDetailResponse: Decodable {
    let songs: [Song]
}

struct SongURLResponse: Decodable {
    let data: [SongURL]
}

struct SongDownloadURLResponse: Decodable {
    let data: SongURL?
}

struct SongURL: Decodable {
    let id: Int
    let url: String?
    let bitrate: Int?
    let format: String?
    let level: String?
    let freeTrialInfo: FreeTrialInfo?

    enum CodingKeys: String, CodingKey {
        case id, url, level
        case bitrate = "br"
        case format = "type"
        case freeTrialInfo
    }
}

struct FreeTrialInfo: Decodable {
    let start: Int?
    let end: Int?
}

struct AlbumDetailResponse: Decodable {
    let album: Album
    let songs: [Song]
}

struct AlbumDynamicResponse: Decodable {
    let code: Int
    let isSub: Bool?
}

struct ArtistDetailResponse: Decodable {
    let artist: Artist
    let hotSongs: [Song]
}

struct ArtistAlbumsResponse: Decodable {
    let hotAlbums: [Album]
}

struct ArtistToplistResponse: Decodable {
    let list: ArtistToplist
}

struct ArtistToplist: Decodable {
    let artists: [Artist]
}

struct SearchResponse: Decodable {
    let result: SearchPayload?
}

struct SearchPayload: Decodable {
    let songs: [Song]?
    let albums: [Album]?
    let artists: [Artist]?
    let playlists: [Playlist]?
    let podcasts: [Podcast]?

    enum CodingKeys: String, CodingKey {
        case songs, albums, artists, playlists
        case podcasts = "djRadios"
    }
}

struct DailySongsResponse: Decodable {
    let data: DailySongsData
}

struct DailySongsData: Decodable {
    let dailySongs: [Song]
}

struct SimilarSongsResponse: Decodable {
    let songs: [Song]
}

struct LyricResponse: Decodable {
    let lrc: LyricContent?
    let yrc: LyricContent?
    let tlyric: LyricContent?
    let ytlrc: LyricContent?
    let romalrc: LyricContent?
    let yromalrc: LyricContent?
    let pureMusic: Bool?
}

struct LyricContent: Decodable {
    let lyric: String?
}

struct AccountResponse: Decodable {
    let code: Int
    let profile: AccountProfile?
}

struct LikedSongsResponse: Decodable {
    let code: Int
    let ids: [Int]
}

struct UserPlaylistsResponse: Decodable {
    let code: Int
    let playlist: [Playlist]
    let more: Bool?
}

struct RecentSongsResponse: Decodable {
    let code: Int
    let data: RecentSongsData?
    let message: String?
}

struct RecentSongsData: Decodable {
    let list: [RecentSongItem]
}

struct RecentSongItem: Decodable {
    let data: Song?
}

struct APIStatusResponse: Decodable {
    let code: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, message
    }
}

struct PodcastCategoriesResponse: Decodable {
    let code: Int
    let categories: [PodcastCategory]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, categories, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        categories = try container.decodeIfPresent(
            [PodcastCategory].self,
            forKey: .categories
        ) ?? []
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
    }
}

struct PodcastCollectionResponse: Decodable {
    let code: Int
    let podcasts: [Podcast]
    let hasMore: Bool?
    let count: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case podcasts = "djRadios"
        case hasMore, count, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        podcasts = try container.decodeIfPresent(
            [Podcast].self,
            forKey: .podcasts
        ) ?? []
        hasMore = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasMore
        )
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
    }
}

struct PodcastPersonalizedResponse: Decodable {
    let code: Int
    let podcasts: [Podcast]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case podcasts = "data"
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        podcasts = try container.decodeIfPresent(
            [Podcast].self,
            forKey: .podcasts
        ) ?? []
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
    }
}

struct PodcastDetailResponse: Decodable {
    let code: Int
    let podcast: Podcast?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case podcast = "data"
        case message
        case msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        podcast = try container.decodeIfPresent(
            Podcast.self,
            forKey: .podcast
        )
        message =
            try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}

struct PodcastProgramsResponse: Decodable {
    let code: Int
    let programs: [PodcastProgram]
    let count: Int
    let more: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, programs, count, more, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        programs = try container.decodeIfPresent(
            [PodcastProgram].self,
            forKey: .programs
        ) ?? []
        count = try container.decodeIfPresent(Int.self, forKey: .count)
            ?? programs.count
        more = try container.decodeIfPresent(Bool.self, forKey: .more)
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
    }
}
