import Foundation
import Observation

@MainActor
@Observable
final class DesktopHomeStore {
    private(set) var recommendedPlaylists: [Playlist] = []
    private(set) var newAlbums: [Album] = []
    private(set) var toplists: [Playlist] = []
    private(set) var topArtists: [Artist] = []
    private(set) var newSongs: [Song] = []
    private(set) var podcastPrograms: [PodcastProgram] = []
    private(set) var featuredPodcasts: [Podcast] = []
    private(set) var podcastCategories: [PodcastCategory] = []
    private(set) var privateRadarPlaylist: Playlist?
    private(set) var phase: LoadingPhase = .loaded
    private(set) var warningMessage: String?

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private var hasLoaded = false

    init(api: NeteaseAPI, settings: AppSettings) {
        self.api = api
        self.settings = settings
    }

    func load(force: Bool = false) async {
        await load(force: force, cancellationRetries: 1)
    }

    private func load(
        force: Bool,
        cancellationRetries: Int
    ) async {
        guard force || !hasLoaded else { return }
        hasLoaded = true
        phase = .loading
        warningMessage = nil

        async let playlistsResult = capture {
            try await self.api.recommendedPlaylists(limit: 16)
        }
        async let albumsResult = capture {
            try await self.api.newAlbums(limit: 16)
        }
        async let toplistsResult = capture {
            try await self.api.toplists()
        }
        async let artistsResult = capture {
            try await self.api.topArtists()
        }
        async let songsResult = capture {
            try await self.api.personalizedNewSongs(
                region: HomeMusicRegion(settingValue: "ALL"),
                limit: 18
            )
        }
        async let programsResult = capture {
            try await self.podcastPrograms()
        }
        async let podcastsResult = capture {
            try await self.podcasts()
        }
        async let categoriesResult = capture {
            try await self.podcastCategories()
        }
        async let homePageResult = capture {
            try await self.api.homePage(refresh: force)
        }

        let results = await (
            playlistsResult,
            albumsResult,
            toplistsResult,
            artistsResult,
            songsResult,
            programsResult,
            podcastsResult,
            categoriesResult,
            homePageResult
        )

        recommendedPlaylists = results.0.value ?? recommendedPlaylists
        newAlbums = results.1.value ?? newAlbums
        toplists = results.2.value ?? toplists
        topArtists = results.3.value ?? topArtists
        newSongs = results.4.value ?? newSongs
        podcastPrograms = results.5.value ?? podcastPrograms
        featuredPodcasts = results.6.value ?? featuredPodcasts
        podcastCategories = results.7.value ?? podcastCategories
        if let payload = results.8.value {
            privateRadarPlaylist = Self.privateRadarPlaylist(in: payload)
        }

        let errors = [
            results.0.error,
            results.1.error,
            results.2.error,
            results.3.error,
            results.4.error,
            results.5.error,
            results.6.error,
            results.7.error,
            results.8.error,
        ].compactMap { $0?.localizedDescription }
        let wasCancelled = [
            results.0.wasCancelled,
            results.1.wasCancelled,
            results.2.wasCancelled,
            results.3.wasCancelled,
            results.4.wasCancelled,
            results.5.wasCancelled,
            results.6.wasCancelled,
            results.7.wasCancelled,
            results.8.wasCancelled,
        ].contains(true)
        let hasContent = !recommendedPlaylists.isEmpty
            || !newAlbums.isEmpty
            || !newSongs.isEmpty
        if hasContent {
            phase = .loaded
            warningMessage = errors.first
        } else if let error = errors.first {
            phase = .failed(error)
        } else if wasCancelled {
            hasLoaded = false
            phase = .loaded
            guard cancellationRetries > 0, !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await load(
                force: true,
                cancellationRetries: cancellationRetries - 1
            )
        } else {
            phase = .loaded
        }
    }

    private func podcastPrograms() async throws -> [PodcastProgram] {
        guard settings.isContentFeatureEnabled(.podcasts) else {
            return []
        }
        return try await api.recommendedPodcastPrograms(limit: 12)
    }

    private func podcasts() async throws -> [Podcast] {
        guard settings.isContentFeatureEnabled(.podcasts) else {
            return []
        }
        return try await api.featuredPodcasts()
    }

    private func podcastCategories() async throws -> [PodcastCategory] {
        guard settings.isContentFeatureEnabled(.podcasts) else {
            return []
        }
        return try await api.podcastCategories()
    }

    private static func privateRadarPlaylist(
        in payload: HomePagePayload
    ) -> Playlist? {
        payload.blocks.first { block in
            let code = block.blockCode.uppercased()
            let title = block.title?
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined() ?? ""
            return code == "HOMEPAGE_BLOCK_MGC_PLAYLIST"
                || title.contains("雷达歌单")
        }?.playlists.first
    }

    private func capture<Value>(
        _ operation: @escaping @MainActor () async throws -> Value
    ) async -> LoadResult<Value> {
        do {
            return LoadResult(
                value: try await operation(),
                error: nil,
                wasCancelled: false
            )
        } catch is CancellationError {
            return LoadResult(value: nil, error: nil, wasCancelled: true)
        } catch let error as URLError where error.code == .cancelled {
            return LoadResult(value: nil, error: nil, wasCancelled: true)
        } catch let error as NSError
            where error.domain == NSURLErrorDomain
                && error.code == NSURLErrorCancelled {
            return LoadResult(value: nil, error: nil, wasCancelled: true)
        } catch {
            return LoadResult(
                value: nil,
                error: error,
                wasCancelled: false
            )
        }
    }
}

private struct LoadResult<Value> {
    let value: Value?
    let error: Error?
    let wasCancelled: Bool
}
