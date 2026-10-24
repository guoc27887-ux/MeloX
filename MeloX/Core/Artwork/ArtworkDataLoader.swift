import Foundation

enum ArtworkDataLoader {
    nonisolated static func data(
        from sourceURL: URL,
        preferredPixelSize: Int
    ) async throws -> Data {
        let url = optimizedURL(
            sourceURL,
            preferredPixelSize: preferredPixelSize
        )
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.setValue(
            "image/jpeg,image/*;q=0.8,*/*;q=0.5",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) =
            try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              !data.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated private static func optimizedURL(
        _ url: URL,
        preferredPixelSize: Int
    ) -> URL {
        guard url.host?.hasSuffix(".music.126.net") == true,
              var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
              ) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll {
            $0.name.caseInsensitiveCompare("param")
                == .orderedSame
        }
        queryItems.append(
            URLQueryItem(
                name: "param",
                value:
                    "\(preferredPixelSize)y\(preferredPixelSize)"
            )
        )
        components.queryItems = queryItems
        return components.url ?? url
    }
}
