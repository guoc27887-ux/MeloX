import Foundation

extension NeteaseAPI {
    func podcastCategories() async throws -> [PodcastCategory] {
        let response: PodcastCategoriesResponse = try await podcastRequest(
            "/api/djradio/category/get"
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        return response.categories.filter { $0.id > 0 }
    }

    func featuredPodcasts() async throws -> [Podcast] {
        let response: PodcastCollectionResponse = try await podcastRequest(
            "/api/djradio/recommend/v1"
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        return response.podcasts
    }

    func personalizedPodcasts(
        limit: Int = 12
    ) async throws -> [Podcast] {
        let response: PodcastPersonalizedResponse =
            try await podcastRequest(
                "/api/djradio/personalize/rcmd",
                data: ["limit": max(limit, 1)]
            )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        return response.podcasts
    }

    func podcasts(
        categoryID: Int,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> PodcastPage {
        let response: PodcastCollectionResponse = try await podcastRequest(
            "/api/djradio/hot",
            data: [
                "cateId": categoryID,
                "limit": min(max(limit, 1), 50),
                "offset": max(offset, 0),
            ]
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        return PodcastPage(
            podcasts: response.podcasts,
            hasMore: response.hasMore
                ?? (offset + response.podcasts.count < (response.count ?? 0)),
            totalCount: response.count
        )
    }

    func podcast(id: Int) async throws -> Podcast {
        let response: PodcastDetailResponse = try await podcastRequest(
            "/api/djradio/v2/get",
            data: ["id": id]
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let podcast = response.podcast else {
            throw APIError.invalidResponse
        }
        return podcast
    }

    func podcastPrograms(
        radioID: Int,
        offset: Int = 0,
        limit: Int = 30,
        ascending: Bool = false
    ) async throws -> PodcastProgramPage {
        let response: PodcastProgramsResponse = try await podcastRequest(
            "/api/dj/program/byradio",
            data: [
                "radioId": radioID,
                "limit": min(max(limit, 1), 50),
                "offset": max(offset, 0),
                "asc": ascending,
            ]
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        let nextOffset = max(offset, 0) + response.programs.count
        return PodcastProgramPage(
            programs: response.programs,
            hasMore: response.more
                ?? (
                    !response.programs.isEmpty
                        && nextOffset < response.count
                ),
            totalCount: response.count
        )
    }

    func subscribedPodcasts(
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> PodcastPage {
        let response: PodcastCollectionResponse = try await podcastRequest(
            "/api/djradio/get/subed",
            data: [
                "limit": min(max(limit, 1), 100),
                "offset": max(offset, 0),
                "total": true,
            ],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        return PodcastPage(
            podcasts: response.podcasts,
            hasMore: response.hasMore
                ?? (
                    max(offset, 0) + response.podcasts.count
                        < (response.count ?? 0)
                ),
            totalCount: response.count
        )
    }

    func setPodcastSubscribed(
        id: Int,
        isSubscribed: Bool
    ) async throws {
        let path = isSubscribed
            ? "/api/djradio/sub"
            : "/api/djradio/unsub"
        let response: APIStatusResponse = try await podcastRequest(
            path,
            data: ["id": id],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
    }

    private func podcastRequest<Response: Decodable>(
        _ path: String,
        data: [String: Any] = [:],
        authenticated: Bool = false
    ) async throws -> Response {
        do {
            // Each route and parameter mirrors the corresponding
            // @neteaseapireborn/api dj_* module, which uses weapi.
            return try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // CFNetwork can receive HTTP 200 with an empty body from a few
            // weapi routes. Keep the same original route and parameters while
            // using the service's eapi transport as the compatibility path.
            return try await client.eapi(
                path,
                data: data,
                authenticated: authenticated
            )
        }
    }
}
