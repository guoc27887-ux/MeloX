import Foundation

nonisolated struct WatchAMLLLyricsClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lyrics(songID: Int) async throws -> String {
        guard let url = URL(
            string: "https://amlldb.bikonoo.com/ncm-lyrics/\(songID).ttml"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 8
        )
        request.setValue(
            "application/ttml+xml, application/xml;q=0.9, text/xml;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let source = String(data: data, encoding: .utf8),
              source.contains("<tt"),
              source != "歌词不存在" else {
            throw URLError(.cannotParseResponse)
        }
        return source
    }
}
