import Foundation

extension NeteaseAPI {
    func songWiki(id: Int) async throws -> SongWiki {
        // Mirrors @neteaseapireborn/api/module/song_wiki_summary.js.
        let response: SongWikiResponse = try await client.eapi(
            "/api/song/play/about/block/page",
            data: ["songId": id],
            authenticated: true
        )
        let message = response.message?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        try validate(
            responseCode: response.code,
            message: message?.isEmpty == false
                ? message
                : L10n.string("ui.error.song_wiki.load_failed")
        )
        guard let payload = response.data else {
            throw APIError.invalidResponse
        }
        return SongWiki(payload: payload)
    }
}
