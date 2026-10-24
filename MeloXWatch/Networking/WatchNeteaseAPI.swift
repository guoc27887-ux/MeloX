import Foundation

@MainActor
final class WatchNeteaseAPI {
    private let client: WatchNeteaseClient
    private let amllLyricsClient = WatchAMLLLyricsClient()

    init(client: WatchNeteaseClient) {
        self.client = client
    }

    func searchSongs(_ keywords: String, limit: Int = 30) async throws -> [WatchSong] {
        let response: SearchResponse = try await client.eapi(
            "/api/search/get",
            data: [
                "s": keywords,
                "type": 1,
                "limit": limit,
                "offset": 0
            ]
        )
        return response.result?.songs ?? []
    }

    func dailySongs() async throws -> [WatchSong] {
        let response: DailySongsResponse = try await client.eapi(
            "/api/v3/discovery/recommend/songs",
            authenticated: true
        )
        return response.data.dailySongs
    }

    func accountProfile() async throws -> WatchAccountProfile {
        let response: AccountResponse = try await client.eapi(
            "/api/w/nuser/account/get",
            authenticated: true
        )
        guard response.code == 200, let profile = response.profile else {
            throw WatchNeteaseError.loginRequired
        }
        return profile
    }

    func userPlaylists(userID: Int) async throws -> [WatchPlaylist] {
        let response: UserPlaylistsResponse = try await client.eapi(
            "/api/user/playlist",
            data: [
                "uid": userID,
                "limit": 2_000,
                "offset": 0,
                "includeVideo": true
            ],
            authenticated: true
        )
        return response.playlist
    }

    func playlist(id: Int) async throws -> WatchPlaylist {
        let response: PlaylistDetailResponse = try await client.eapi(
            "/api/v6/playlist/detail",
            data: ["id": id, "n": 100, "s": 8]
        )
        var playlist = response.playlist
        let trackIDs = playlist.trackIDs.map(\.id)
        guard !trackIDs.isEmpty else { return playlist }

        var detailsByID = Dictionary(
            playlist.tracks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let missingIDs = trackIDs.filter { detailsByID[$0] == nil }
        for start in stride(from: 0, to: missingIDs.count, by: 100) {
            try Task.checkCancellation()
            let end = min(start + 100, missingIDs.count)
            for song in try await songDetails(
                ids: Array(missingIDs[start..<end])
            ) {
                detailsByID[song.id] = song
            }
        }
        playlist.tracks = trackIDs.compactMap { detailsByID[$0] }
        return playlist
    }

    func songDetails(ids: [Int]) async throws -> [WatchSong] {
        guard !ids.isEmpty else { return [] }
        let songs = ids.map { ["id": $0] }
        let data = try JSONSerialization.data(withJSONObject: songs)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WatchNeteaseError.requestEncoding
        }
        let response: SongDetailResponse = try await client.eapi(
            "/api/v3/song/detail",
            data: ["c": json]
        )
        return response.songs
    }

    func playbackSource(
        for song: WatchSong,
        quality: WatchStreamingQuality = .high
    ) async throws -> WatchPlaybackSource {
        for candidate in quality.playbackCandidates(
            for: song.audioAvailability
        ) {
            do {
                return try await requestPlaybackSource(
                    id: song.id,
                    quality: candidate
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch WatchNeteaseError.noPlayableSource {
                continue
            }
        }
        throw WatchNeteaseError.noPlayableSource
    }

    private func requestPlaybackSource(
        id: Int,
        quality: WatchStreamingQuality
    ) async throws -> WatchPlaybackSource {
        // Mirrors @neteaseapireborn/api/module/song_url_v1.js.
        var data: [String: Any] = [
            "ids": "[\(id)]",
            "level": quality.apiLevel,
            "encodeType": "flac",
        ]
        if quality.requiresImmersiveType {
            data["immerseType"] = "c51"
        }
        let response: SongURLResponse = try await client.eapi(
            "/api/song/enhance/player/url/v1",
            data: data
        )
        guard let source = response.data.first(where: { $0.id == id }),
              let string = source.url,
              var components = URLComponents(string: string) else {
            throw WatchNeteaseError.noPlayableSource
        }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }
        guard let url = components.url else {
            throw WatchNeteaseError.noPlayableSource
        }
        return WatchPlaybackSource(
            url: url,
            quality: source.level.flatMap(
                WatchStreamingQuality.init(apiLevel:)
            )
        )
    }

    func lyrics(id: Int) async throws -> [WatchLyricLine] {
        let neteaseTask = Task {
            try await client.eapiData(
                "/api/song/lyric/v1",
                data: [
                    "id": id,
                    "cp": false,
                    "tv": 0,
                    "lv": 0,
                    "rv": 0,
                    "kv": 0,
                    "yv": 0,
                    "ytv": 0,
                    "yrv": 0
                ]
            )
        }

        do {
            let source = try await amllLyricsClient.lyrics(songID: id)
            let ttmlLyrics = await Task.detached(priority: .utility) {
                WatchTTMLLyricParser.parse(source)
            }.value
            try Task.checkCancellation()
            if !ttmlLyrics.isEmpty {
                neteaseTask.cancel()
                return ttmlLyrics
            }
        } catch is CancellationError {
            neteaseTask.cancel()
            throw CancellationError()
        } catch {
            // AMLL is an optional high-fidelity source. The direct NetEase
            // lyric route below remains the offline/failure fallback.
        }

        let responseData = try await neteaseTask.value

        let processingTask = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let response = try Self.decodeLyricsResponse(
                from: responseData
            )
            try Task.checkCancellation()
            let parsedLyrics = WatchLyricParser.parse(
                yrc: response.yrc?.lyric ?? "",
                lrc: response.lrc?.lyric ?? "",
                translatedYRC: response.ytlrc?.lyric ?? "",
                translatedLRC: response.tlyric?.lyric ?? "",
                romanizedYRC: response.yromalrc?.lyric ?? "",
                romanizedLRC: response.romalrc?.lyric ?? ""
            )
            try Task.checkCancellation()
            return parsedLyrics
        }

        return try await withTaskCancellationHandler {
            let parsedLyrics = try await processingTask.value
            try Task.checkCancellation()
            return parsedLyrics
        } onCancel: {
            processingTask.cancel()
        }
    }

    func makeQRLoginKey() async throws -> String {
        let response: QRKeyResponse = try await client.eapi(
            "/api/login/qrcode/unikey",
            data: ["type": 3]
        )
        guard let key = response.unikey ?? response.data?.unikey,
              !key.isEmpty else {
            throw WatchNeteaseError.invalidResponse
        }
        return key
    }

    func checkQRLogin(key: String) async throws -> WatchQRLoginResult {
        let response: WatchNeteaseResponse<QRCheckResponse> =
            try await client.eapiResponse(
                "/api/login/qrcode/client/login",
                data: ["key": key, "type": 3]
            )
        return WatchQRLoginResult(
            code: response.value.code,
            message: response.value.message
                ?? response.value.nickname,
            cookie: response.value.cookie
                ?? Self.cookieHeader(response.cookies)
        )
    }

    private static func cookieHeader(_ cookies: [HTTPCookie]) -> String {
        let usable = cookies.filter { cookie in
            cookie.expiresDate.map { $0 > Date() } ?? true
        }
        return usable
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    private nonisolated static func decodeLyricsResponse(
        from data: Data
    ) throws -> LyricsResponse {
        do {
            return try JSONDecoder().decode(
                LyricsResponse.self,
                from: data
            )
        } catch {
            let payload = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
            let code = payload?["code"] as? Int ?? 200
            let message = payload?["message"] as? String
                ?? payload?["msg"] as? String
                ?? error.localizedDescription
            throw WatchNeteaseError.server(code, message)
        }
    }
}

struct WatchQRLoginResult {
    let code: Int
    let message: String?
    let cookie: String
}

private struct SearchResponse: Decodable {
    let result: SearchPayload?
}

private struct SearchPayload: Decodable {
    let songs: [WatchSong]?
}

private struct DailySongsResponse: Decodable {
    let data: DailySongsPayload
}

private struct DailySongsPayload: Decodable {
    let dailySongs: [WatchSong]
}

private struct AccountResponse: Decodable {
    let code: Int
    let profile: WatchAccountProfile?
}

private struct UserPlaylistsResponse: Decodable {
    let playlist: [WatchPlaylist]
}

private struct PlaylistDetailResponse: Decodable {
    let playlist: WatchPlaylist
}

private struct SongDetailResponse: Decodable {
    let songs: [WatchSong]
}

private struct SongURLResponse: Decodable {
    let data: [SongURLPayload]
}

private struct SongURLPayload: Decodable {
    let id: Int
    let url: String?
    let level: String?
}

private nonisolated struct LyricsResponse: Decodable, Sendable {
    let lrc: LyricContent?
    let yrc: LyricContent?
    let tlyric: LyricContent?
    let ytlrc: LyricContent?
    let romalrc: LyricContent?
    let yromalrc: LyricContent?
}

private nonisolated struct LyricContent: Decodable, Sendable {
    let lyric: String?
}

private struct QRKeyResponse: Decodable {
    let unikey: String?
    let data: QRKeyPayload?
}

private struct QRKeyPayload: Decodable {
    let unikey: String?
}

private struct QRCheckResponse: Decodable {
    let code: Int
    let message: String?
    let nickname: String?
    let cookie: String?
}
