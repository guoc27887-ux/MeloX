import Foundation
import Observation

@MainActor
@Observable
final class MusicCollectionDownloadCoordinator {
    private(set) var isSelecting = false
    private(set) var selectedSongIDs: Set<Int> = []
    private(set) var isPreparing = false
    private(set) var preparingSongCount = 0
    private(set) var errorMessage: String?

    func beginSelection() {
        selectedSongIDs.removeAll()
        isSelecting = true
    }

    func finishSelection() {
        selectedSongIDs.removeAll()
        isSelecting = false
    }

    func toggleSelection(songID: Int) {
        if selectedSongIDs.contains(songID) {
            selectedSongIDs.remove(songID)
        } else {
            selectedSongIDs.insert(songID)
        }
    }

    func toggleAll(songIDs: Set<Int>) {
        guard !songIDs.isEmpty else { return }
        if songIDs.isSubset(of: selectedSongIDs) {
            selectedSongIDs.subtract(songIDs)
        } else {
            selectedSongIDs.formUnion(songIDs)
        }
    }

    func retainSelection(in songIDs: Set<Int>) {
        selectedSongIDs.formIntersection(songIDs)
    }

    func clearError() {
        errorMessage = nil
    }

    func downloadAll(
        in playlist: Playlist,
        quality: MusicQuality,
        api: NeteaseAPI,
        downloads: DownloadStore
    ) async {
        await prepareDownloads(
            songIDs: Self.songIDs(in: playlist),
            loadedSongs: playlist.tracks,
            requestedSongIDs: nil,
            quality: quality,
            finishesSelection: false,
            api: api,
            downloads: downloads
        )
    }

    func downloadSelection(
        in playlist: Playlist,
        quality: MusicQuality,
        api: NeteaseAPI,
        downloads: DownloadStore
    ) async {
        await prepareDownloads(
            songIDs: Self.songIDs(in: playlist),
            loadedSongs: playlist.tracks,
            requestedSongIDs: selectedSongIDs,
            quality: quality,
            finishesSelection: true,
            api: api,
            downloads: downloads
        )
    }

    func downloadAll(
        in songs: [Song],
        quality: MusicQuality,
        api: NeteaseAPI,
        downloads: DownloadStore
    ) async {
        await prepareDownloads(
            songIDs: Self.songIDs(in: songs),
            loadedSongs: songs,
            requestedSongIDs: nil,
            quality: quality,
            finishesSelection: false,
            api: api,
            downloads: downloads
        )
    }

    func downloadSelection(
        in songs: [Song],
        quality: MusicQuality,
        api: NeteaseAPI,
        downloads: DownloadStore
    ) async {
        await prepareDownloads(
            songIDs: Self.songIDs(in: songs),
            loadedSongs: songs,
            requestedSongIDs: selectedSongIDs,
            quality: quality,
            finishesSelection: true,
            api: api,
            downloads: downloads
        )
    }

    static func songIDs(in playlist: Playlist) -> [Int] {
        uniqueSongIDs(
            playlist.trackIDs.map(\.id) + playlist.tracks.map(\.id)
        )
    }

    static func songIDs(in songs: [Song]) -> [Int] {
        uniqueSongIDs(songs.map(\.id))
    }

    private static func uniqueSongIDs(
        _ songIDs: [Int]
    ) -> [Int] {
        var seenSongIDs: Set<Int> = []
        return songIDs.filter { songID in
            songID > 0 && seenSongIDs.insert(songID).inserted
        }
    }

    private func prepareDownloads(
        songIDs: [Int],
        loadedSongs: [Song],
        requestedSongIDs: Set<Int>?,
        quality: MusicQuality,
        finishesSelection: Bool,
        api: NeteaseAPI,
        downloads: DownloadStore
    ) async {
        guard !isPreparing else { return }

        let unavailableSongIDs = Set(downloads.downloads.map(\.id))
            .union(downloads.activeDownloads.keys)
        let orderedSongIDs = songIDs.filter { songID in
            requestedSongIDs?.contains(songID) ?? true
        }
        let downloadableSongIDs = orderedSongIDs.filter {
            !unavailableSongIDs.contains($0)
        }

        guard !downloadableSongIDs.isEmpty else {
            if finishesSelection {
                finishSelection()
            }
            return
        }

        isPreparing = true
        preparingSongCount = downloadableSongIDs.count
        errorMessage = nil
        defer {
            isPreparing = false
            preparingSongCount = 0
        }

        do {
            let songs = try await resolveSongs(
                withIDs: downloadableSongIDs,
                loadedSongs: loadedSongs,
                api: api
            )
            try Task.checkCancellation()
            guard !songs.isEmpty else {
                throw MusicCollectionDownloadPreparationError.noAvailableSongs
            }

            downloads.start(songs, quality: quality)
            if finishesSelection {
                finishSelection()
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveSongs(
        withIDs orderedSongIDs: [Int],
        loadedSongs: [Song],
        api: NeteaseAPI
    ) async throws -> [Song] {
        var songsByID: [Int: Song] = [:]
        for song in loadedSongs {
            songsByID[song.id] = song
        }

        let missingSongIDs = orderedSongIDs.filter { songsByID[$0] == nil }
        for startIndex in stride(from: 0, to: missingSongIDs.count, by: 100) {
            try Task.checkCancellation()
            let endIndex = min(startIndex + 100, missingSongIDs.count)
            let pageSongIDs = Array(missingSongIDs[startIndex..<endIndex])
            for song in try await api.songDetails(ids: pageSongIDs) {
                songsByID[song.id] = song
            }
        }

        return orderedSongIDs.compactMap { songsByID[$0] }
    }
}

private enum MusicCollectionDownloadPreparationError: LocalizedError {
    case noAvailableSongs

    var errorDescription: String? {
        L10n.string("ui.downloads.no_downloadable_songs")
    }
}
