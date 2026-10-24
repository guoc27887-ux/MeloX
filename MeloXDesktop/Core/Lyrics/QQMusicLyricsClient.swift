import Foundation

nonisolated struct QQMusicLyricsClient: Sendable {
    private let session: URLSession
    private let matchStore: QQMusicLyricMatchStore

    init(
        session: URLSession = .shared,
        matchStore: QQMusicLyricMatchStore = QQMusicLyricMatchStore()
    ) {
        self.session = session
        self.matchStore = matchStore
    }

    func lyrics(for song: LyricsSongMetadata) async throws -> QQLyricPayload {
        let match: QQMusicTrackMatch
        if let stored = await matchStore.match(for: song.id),
           QQMusicLyricMatcher.isPlausible(stored, for: song) {
            match = stored
        } else {
            await matchStore.remove(for: song.id)
            guard let searched = try await bestMatch(for: song) else {
                throw LyricSourceError.noLyrics
            }
            match = searched
            await matchStore.set(searched, for: song.id)
        }

        let primary = try await lyricResponse(for: match, requestsQRC: true)
        let verbatim = primary.qrcT != 0
            ? QQMusicLyricDecoder.decode(primary.lyric)
            : nil
        let primaryLine = primary.qrcT == 0
            ? QQMusicLyricDecoder.decode(primary.lyric)
            : nil
        let translation = QQMusicLyricDecoder.decode(primary.translation)
        let romanization = QQMusicLyricDecoder.decode(primary.romanization)

        var fallbackLine: String?
        if primary.qrcT != 0,
           let fallback = try? await lyricResponse(
                for: match,
                requestsQRC: false
           ) {
            fallbackLine = QQMusicLyricDecoder.decode(fallback.lyric)
        }

        let payload = QQLyricPayload(
            verbatim: normalized(verbatim),
            lineSynchronized: normalized(fallbackLine ?? primaryLine),
            translation: normalized(translation),
            romanization: normalized(romanization)
        )
        guard payload.verbatim != nil || payload.lineSynchronized != nil else {
            throw LyricSourceError.noLyrics
        }
        return payload
    }

    private func bestMatch(
        for song: LyricsSongMetadata
    ) async throws -> QQMusicTrackMatch? {
        for query in QQMusicLyricMatcher.searchQueries(for: song) {
            let candidates = try await search(query: query)
            if let match = QQMusicLyricMatcher.bestCandidate(
                in: candidates,
                for: song
            ) {
                return match
            }
        }
        return nil
    }

    private func search(query: String) async throws -> [QQMusicTrackMatch] {
        let body: [String: Any] = [
            "comm": [
                "ct": 11,
                "cv": "1003006",
                "uin": 0,
                "tmeAppID": "qqmusiclight",
            ],
            "req_0": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": 20,
                    "page_num": 1,
                    "query": query,
                    "search_type": 0,
                    "grp": 1,
                ],
            ],
        ]
        let response: QQSearchResponse = try await request(body: body)
        return response.request.data.body.song.list.map { item in
            QQMusicTrackMatch(
                id: item.id,
                title: item.title,
                album: item.album.title,
                artist: item.singers.map(\.name).joined(separator: ","),
                durationSeconds: item.interval
            )
        }
    }

    private func lyricResponse(
        for song: QQMusicTrackMatch,
        requestsQRC: Bool
    ) async throws -> QQLyricResponse.Data {
        let encode: (String) -> String = {
            Data($0.utf8).base64EncodedString()
        }
        let body: [String: Any] = [
            "comm": [
                "_channelid": "",
                "_os_version": "6.2.9200-2",
                "authst": "",
                "ct": 11,
                "cv": "1003006",
                "patch": "118",
                "psrf_access_token_expiresAt": 0,
                "psrf_qqaccess_token": "",
                "psrf_qqopenid": "",
                "psrf_qqunionid": "",
                "tmeAppID": "qqmusiclight",
                "tmeLoginType": 0,
                "uin": "",
                "wid": "",
            ],
            "music.musichallSong.PlayLyricInfo.GetPlayLyricInfo": [
                "method": "GetPlayLyricInfo",
                "module": "music.musichallSong.PlayLyricInfo",
                "param": [
                    "albumName": encode(song.album),
                    "crypt": 1,
                    "ct": 19,
                    "cv": 2111,
                    "interval": song.durationSeconds,
                    "lrc_t": 0,
                    "qrc": requestsQRC ? 1 : 0,
                    "qrc_t": 0,
                    "roma": 1,
                    "roma_t": 0,
                    "singerName": encode(song.artist),
                    "songID": song.id,
                    "songName": encode(song.title),
                    "trans": 1,
                    "trans_t": 0,
                    "type": 0,
                ],
            ],
        ]
        let response: QQLyricResponse = try await request(body: body)
        return response.request.data
    }

    private func request<Response: Decodable & Sendable>(
        body: [String: Any]
    ) async throws -> Response {
        guard let url = URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg") else {
            throw LyricSourceError.invalidResponse
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 Chrome/91.0.4472.164 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LyricSourceError.invalidResponse
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

private nonisolated struct QQSearchResponse: Decodable, Sendable {
    let request: SearchRequest

    enum CodingKeys: String, CodingKey {
        case request = "req_0"
    }

    struct SearchRequest: Decodable, Sendable {
        let data: SearchData
    }

    struct SearchData: Decodable, Sendable {
        let body: SearchBody
    }

    struct SearchBody: Decodable, Sendable {
        let song: SongList
    }

    struct SongList: Decodable, Sendable {
        let list: [Song]
    }

    struct Song: Decodable, Sendable {
        let id: Int64
        let title: String
        let interval: Int
        let album: Album
        let singers: [Singer]

        enum CodingKeys: String, CodingKey {
            case id, title, interval, album
            case singers = "singer"
        }
    }

    struct Album: Decodable, Sendable {
        let title: String
    }

    struct Singer: Decodable, Sendable {
        let name: String
    }
}

private nonisolated struct QQLyricResponse: Decodable, Sendable {
    let request: LyricRequest

    enum CodingKeys: String, CodingKey {
        case request = "music.musichallSong.PlayLyricInfo.GetPlayLyricInfo"
    }

    struct LyricRequest: Decodable, Sendable {
        let data: Data
    }

    struct Data: Decodable, Sendable {
        let lyric: String
        let translation: String
        let romanization: String
        let qrcT: Int

        enum CodingKeys: String, CodingKey {
            case lyric
            case translation = "trans"
            case romanization = "roma"
            case qrcT = "qrc_t"
        }
    }
}
