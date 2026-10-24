import Foundation
import OSLog

@MainActor
final class LyricsLiveActivityArtworkStore {
    private static let failedRequestRetryInterval: TimeInterval = 15
    private static let legacyAppGroupIdentifier =
        "group.moye.MeloX"
    private static let legacyArtworkDirectoryName =
        "LyricsLiveActivityArtwork"
    private static let logger = Logger(
        subsystem: "moye.MeloX",
        category: "LyricsLiveActivityArtwork"
    )

    private struct Request: Equatable {
        let songID: Int
        let url: URL
    }

    private struct CachedArtwork {
        let request: Request
        let data: Data
    }

    private var request: Request?
    private var failedRequest: Request?
    private var failedRequestDate: Date?
    private var cachedArtwork: CachedArtwork?
    private var task: Task<Void, Never>?

    init() {
        removeLegacyDiskCache()
    }

    deinit {
        task?.cancel()
    }

    func cachedData(songID: Int, url: URL?) -> Data? {
        guard let url,
              let cachedArtwork,
              cachedArtwork.request
                == Request(songID: songID, url: url) else {
            return nil
        }
        return cachedArtwork.data
    }

    func prepare(
        songID: Int,
        url: URL?,
        completion: @escaping @MainActor (Data) -> Void
    ) {
        guard let url else { return }
        let newRequest = Request(songID: songID, url: url)
        guard canAttempt(newRequest) else { return }

        if let data = cachedData(songID: songID, url: url) {
            failedRequest = nil
            failedRequestDate = nil
            completion(data)
            return
        }
        guard request != newRequest || task == nil else { return }

        task?.cancel()
        cachedArtwork = nil
        failedRequest = nil
        failedRequestDate = nil
        request = newRequest
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sourceData = try await ArtworkDataLoader.data(
                    from: url,
                    preferredPixelSize:
                        LyricsLiveActivityArtworkPolicy
                            .maximumPixelSize
                )
                try Task.checkCancellation()

                let jpegData = await Task.detached(
                    priority: .utility
                ) {
                    ArtworkThumbnailEncoder.jpegData(
                        from: sourceData,
                        maximumPixelSize:
                            LyricsLiveActivityArtworkPolicy
                                .maximumPixelSize,
                        compressionQuality: 0.64,
                        maximumByteCount:
                            LyricsLiveActivityArtworkPolicy
                                .maximumJPEGByteCount
                    )
                }.value
                try Task.checkCancellation()
                guard let jpegData else {
                    throw URLError(.cannotDecodeContentData)
                }
                guard request == newRequest else { return }

                cachedArtwork = CachedArtwork(
                    request: newRequest,
                    data: jpegData
                )
                failedRequest = nil
                failedRequestDate = nil
                request = nil
                task = nil
                Self.logger.notice(
                    "Prepared embedded Live Activity artwork (\(jpegData.count, privacy: .public) bytes)"
                )
                completion(jpegData)
            } catch is CancellationError {
                guard request == newRequest else { return }
                request = nil
                task = nil
            } catch {
                guard request == newRequest else { return }
                failedRequest = newRequest
                failedRequestDate = .now
                request = nil
                task = nil
                Self.logger.error(
                    "Failed to prepare Live Activity artwork: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func clear() {
        task?.cancel()
        task = nil
        request = nil
        failedRequest = nil
        failedRequestDate = nil
        cachedArtwork = nil
    }

    private func canAttempt(
        _ newRequest: Request,
        at date: Date = .now
    ) -> Bool {
        guard failedRequest == newRequest,
              let failedRequestDate else {
            return true
        }
        return date.timeIntervalSince(failedRequestDate)
            >= Self.failedRequestRetryInterval
    }

    private func removeLegacyDiskCache() {
        guard let containerURL =
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier:
                    Self.legacyAppGroupIdentifier
            )
        else {
            return
        }
        let directory = containerURL.appending(
            path: Self.legacyArtworkDirectoryName,
            directoryHint: .isDirectory
        )
        guard FileManager.default.fileExists(
            atPath: directory.path
        ) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Self.logger.error(
                "Failed to remove legacy Live Activity artwork cache: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
