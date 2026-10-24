import Foundation
import Observation

nonisolated struct DownloadStorageRepairResult: Sendable {
    static let empty = DownloadStorageRepairResult(
        removedMissingRecordCount: 0,
        removedUntrackedByteCount: 0
    )

    let removedMissingRecordCount: Int
    let removedUntrackedByteCount: Int64

    var repairedAnything: Bool {
        removedMissingRecordCount > 0
            || removedUntrackedByteCount > 0
    }
}

@MainActor
@Observable
final class DownloadStore {
    private struct QueuedDownload {
        let requestID: UUID
        let song: Song
        let quality: MusicQuality
    }

    private(set) var downloads: [DownloadedSong]
    private(set) var activeDownloads: [Int: ActiveSongDownload] = [:]
    private(set) var errorMessage: String?

    var activeSongs: [Int: Song] {
        activeDownloads.mapValues(\.song)
    }

    var downloadedSongs: [Song] {
        downloads.map(\.song)
    }

    var totalByteCount: Int64 {
        downloads.reduce(0) { $0 + $1.byteCount }
    }

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let storage: DownloadStorage

    @ObservationIgnored
    private let transferClient: DownloadTransferClient

    @ObservationIgnored
    private let database: DownloadDatabase?

    @ObservationIgnored
    private var tasks: [Int: Task<Void, Never>] = [:]

    @ObservationIgnored
    private var requestIDs: [Int: UUID] = [:]

    @ObservationIgnored
    private var queuedDownloads: [QueuedDownload] = []

    @ObservationIgnored
    private let maximumConcurrentDownloadCount = 3

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        storage: DownloadStorage? = nil,
        transferClient: DownloadTransferClient? = nil,
        database: DownloadDatabase? = nil
    ) {
        let storage = storage ?? DownloadStorage()
        self.api = api
        self.settings = settings
        self.storage = storage
        self.transferClient = transferClient ?? DownloadTransferClient()

        var resolvedDatabase: DownloadDatabase?
        var resolvedDownloads: [DownloadedSong] = []
        var initialErrorMessage: String?
        do {
            let openedDatabase: DownloadDatabase
            if let database {
                openedDatabase = database
            } else {
                openedDatabase = try DownloadDatabase()
            }

            let storedDownloads = try openedDatabase.fetchDownloads()
            resolvedDownloads = storedDownloads.filter {
                storage.containsFile(named: $0.fileName)
            }
            let missingSongIDs = Set(storedDownloads.map(\.id))
                .subtracting(resolvedDownloads.map(\.id))
            for songID in missingSongIDs {
                try openedDatabase.removeDownload(songID: songID)
            }
            resolvedDatabase = openedDatabase
        } catch {
            initialErrorMessage = L10n.format("ui.error.download.open_database_failed", error.localizedDescription)
        }

        self.database = resolvedDatabase
        downloads = resolvedDownloads
        errorMessage = initialErrorMessage
    }

    func contains(songID: Int) -> Bool {
        downloads.contains { $0.id == songID }
    }

    func isDownloading(songID: Int) -> Bool {
        activeDownloads[songID] != nil
    }

    func localPlaybackSource(songID: Int) -> PlaybackSource? {
        guard let download = downloads.first(where: { $0.id == songID }) else {
            return nil
        }
        guard storage.containsFile(named: download.fileName) else {
            removeMissingDownload(songID: songID)
            return nil
        }
        return PlaybackSource(
            url: storage.fileURL(fileName: download.fileName),
            bitrate: download.bitrate,
            format: download.format,
            quality: download.quality
        )
    }

    func start(_ song: Song, quality: MusicQuality) {
        start([song], quality: quality)
    }

    func start(_ songs: [Song], quality: MusicQuality) {
        guard AppFeatureAvailability.downloads,
              settings.isContentFeatureEnabled(.downloads) else {
            return
        }
        guard database != nil else {
            errorMessage = DownloadDatabaseError.unavailable.localizedDescription
            return
        }

        errorMessage = nil

        var enqueuedSongIDs: Set<Int> = []
        for song in songs where enqueuedSongIDs.insert(song.id).inserted {
            guard !contains(songID: song.id),
                  !isDownloading(songID: song.id) else {
                continue
            }

            let requestID = UUID()
            requestIDs[song.id] = requestID
            activeDownloads[song.id] = ActiveSongDownload(
                song: song,
                quality: quality,
                receivedByteCount: 0,
                expectedByteCount: nil
            )
            queuedDownloads.append(
                QueuedDownload(
                    requestID: requestID,
                    song: song,
                    quality: quality
                )
            )
        }

        startQueuedDownloadsIfNeeded()
    }

    func recordPlayback(_ song: Song) {
        guard AppFeatureAvailability.downloads,
              settings.isContentFeatureEnabled(.downloads) else {
            return
        }
        do {
            guard let database else { return }
            let count = try database.recordPlayback(songID: song.id)
            guard settings.automaticallyCachesFrequentlyPlayedSongs,
                  count >= settings.automaticCachePlaybackThreshold,
                  !contains(songID: song.id),
                  !isDownloading(songID: song.id) else {
                return
            }
            start(song, quality: settings.automaticCacheQuality)
        } catch {
            errorMessage = L10n.format("ui.error.download.record_play_count_failed", error.localizedDescription)
        }
    }

    func cancel(songID: Int) {
        queuedDownloads.removeAll { $0.song.id == songID }
        let task = tasks[songID]
        if let task {
            task.cancel()
            return
        }

        requestIDs[songID] = nil
        activeDownloads[songID] = nil
        startQueuedDownloadsIfNeeded()
    }

    func remove(songID: Int) {
        cancel(songID: songID)
        guard let index = downloads.firstIndex(where: { $0.id == songID }) else { return }
        let download = downloads[index]
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
            downloads.remove(at: index)
            try storage.removeFile(named: download.fileName)
        } catch {
            errorMessage = L10n.format("ui.error.download.delete_song_failed", error.localizedDescription)
        }
    }

    func discardInvalidDownload(songID: Int) {
        cancel(songID: songID)
        guard let index = downloads.firstIndex(where: { $0.id == songID }) else { return }
        let download = downloads.remove(at: index)

        var failures: [String] = []
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
        } catch {
            failures.append(error.localizedDescription)
        }
        do {
            try storage.removeFile(named: download.fileName)
        } catch {
            failures.append(error.localizedDescription)
        }

        if !failures.isEmpty {
            errorMessage = L10n.format(
                "ui.error.download.partial_cache_cleanup",
                failures.joined(separator: L10n.string("ui.common.list_separator"))
            )
        }
    }

    func removeAll() {
        queuedDownloads.removeAll()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        requestIDs.removeAll()
        activeDownloads.removeAll()
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeAllDownloads()
            downloads.removeAll()
            try storage.removeAllFiles()
        } catch {
            errorMessage = L10n.format("ui.error.download.clear_failed", error.localizedDescription)
        }
    }

    @discardableResult
    func repairStorage() -> DownloadStorageRepairResult {
        errorMessage = nil
        do {
            guard let database else {
                throw DownloadDatabaseError.unavailable
            }

            let missingDownloads = downloads.filter {
                !storage.containsFile(named: $0.fileName)
            }
            let missingSongIDs = Set(
                missingDownloads.map(\.id)
            )
            try database.removeDownloads(
                songIDs: missingSongIDs
            )
            if !missingDownloads.isEmpty {
                downloads.removeAll {
                    missingSongIDs.contains($0.id)
                }
            }

            let removedByteCount =
                try storage.removeUntrackedFiles(
                    keeping: Set(
                        downloads.map(\.fileName)
                    )
                )
            return DownloadStorageRepairResult(
                removedMissingRecordCount:
                    missingDownloads.count,
                removedUntrackedByteCount:
                    removedByteCount
            )
        } catch {
            errorMessage =
                L10n.format("ui.error.download.repair_failed", error.localizedDescription)
            return .empty
        }
    }

    func resetAutomaticCacheHistory() {
        errorMessage = nil
        do {
            guard let database else {
                throw DownloadDatabaseError.unavailable
            }
            try database.clearPlaybackCounts()
        } catch {
            errorMessage =
                L10n.format("ui.error.download.reset_cache_count_failed", error.localizedDescription)
        }
    }

    func optimizeStorageDatabase() {
        errorMessage = nil
        do {
            guard let database else {
                throw DownloadDatabaseError.unavailable
            }
            try database.optimizeStorage()
        } catch {
            errorMessage =
                L10n.format("ui.error.download.optimize_database_failed", error.localizedDescription)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func download(
        _ song: Song,
        quality: MusicQuality,
        requestID: UUID
    ) async {
        defer {
            if requestIDs[song.id] == requestID {
                tasks[song.id] = nil
                requestIDs[song.id] = nil
                activeDownloads[song.id] = nil
            }
            startQueuedDownloadsIfNeeded()
        }

        do {
            let source = try await api.downloadSource(
                for: song,
                quality: quality
            )
            try Task.checkCancellation()
            let transfer = try await transferClient.download(from: source.url) { [weak self] progress in
                self?.updateProgress(
                    progress,
                    songID: song.id,
                    requestID: requestID
                )
            }
            let temporaryURL = transfer.temporaryURL
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            try Task.checkCancellation()
            guard let httpResponse = transfer.response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw DownloadError.invalidResponse
            }

            let installed = try storage.installDownloadedFile(
                from: temporaryURL,
                songID: song.id,
                format: source.format,
                sourceURL: source.url
            )

            let completedDownload = DownloadedSong(
                song: song,
                fileName: installed.fileName,
                byteCount: installed.byteCount,
                bitrate: source.bitrate,
                format: source.format,
                quality: source.quality ?? quality,
                downloadedAt: Date()
            )
            do {
                guard let database else { throw DownloadDatabaseError.unavailable }
                try database.save(completedDownload)
                downloads.removeAll { $0.id == song.id }
                downloads.insert(completedDownload, at: 0)
            } catch {
                try? storage.removeFile(named: installed.fileName)
                throw error
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard requestIDs[song.id] == requestID else { return }
            errorMessage = L10n.format("ui.error.download.song_failed", song.name, error.localizedDescription)
        }
    }

    private func removeMissingDownload(songID: Int) {
        downloads.removeAll { $0.id == songID }
        do {
            guard let database else { throw DownloadDatabaseError.unavailable }
            try database.removeDownload(songID: songID)
        } catch {
            errorMessage = L10n.format("ui.error.download.update_record_failed", error.localizedDescription)
        }
    }

    private func updateProgress(
        _ progress: DownloadTransferProgress,
        songID: Int,
        requestID: UUID
    ) {
        guard requestIDs[songID] == requestID,
              var download = activeDownloads[songID] else {
            return
        }
        download.receivedByteCount = progress.receivedByteCount
        download.expectedByteCount = progress.expectedByteCount
        activeDownloads[songID] = download
    }

    private func startQueuedDownloadsIfNeeded() {
        while tasks.count < maximumConcurrentDownloadCount,
              !queuedDownloads.isEmpty {
            let queuedDownload = queuedDownloads.removeFirst()
            let songID = queuedDownload.song.id
            guard requestIDs[songID] == queuedDownload.requestID,
                  activeDownloads[songID] != nil,
                  !contains(songID: songID) else {
                if requestIDs[songID] == queuedDownload.requestID {
                    requestIDs[songID] = nil
                    activeDownloads[songID] = nil
                }
                continue
            }

            tasks[songID] = Task { [weak self] in
                await self?.download(
                    queuedDownload.song,
                    quality: queuedDownload.quality,
                    requestID: queuedDownload.requestID
                )
            }
        }
    }
}
