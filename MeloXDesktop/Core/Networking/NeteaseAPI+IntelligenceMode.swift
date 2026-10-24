import Foundation

extension NeteaseAPI {
    func intelligenceModeSongs(
        seedSongID: Int,
        playlistID: Int
    ) async throws -> [Song] {
        // Mirrors @neteaseapireborn/api/module/playmode_intelligence_list.js.
        let response: IntelligenceModeResponse = try await client.eapi(
            "/api/playmode/intelligence/list",
            data: [
                "songId": seedSongID,
                "type": "fromPlayOne",
                "playlistId": playlistID,
                "startMusicId": seedSongID,
                "count": 1,
            ],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )

        let songIDs = response.data
            .map(\.id)
            .filter { $0 > 0 }
        guard !songIDs.isEmpty else {
            throw IntelligenceModeError.emptyRecommendations
        }

        let songs = try await songDetails(ids: songIDs)
        var songsByID: [Int: Song] = [:]
        for song in songs {
            songsByID[song.id] = song
        }
        let orderedSongs = songIDs.compactMap { songsByID[$0] }
        guard !orderedSongs.isEmpty else {
            throw IntelligenceModeError.emptyRecommendations
        }
        return orderedSongs
    }
}

private enum IntelligenceModeError: LocalizedError {
    case emptyRecommendations

    var errorDescription: String? {
        L10n.string("ui.error.heart_mode.no_playable_song")
    }
}
