import Foundation
import OSLog
import UserNotifications

@MainActor
final class LyricsNotificationArtworkStore {
    private static let failedRequestRetryInterval: TimeInterval = 15
    nonisolated private static let preferredPixelSize = 256
    private static let logger = Logger(
        subsystem: "moye.MeloX",
        category: "LyricsNotificationArtwork"
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
    private let attachmentStager =
        LyricsNotificationAttachmentStager()

    deinit {
        task?.cancel()
    }

    func prepare(songID: Int, url: URL?) {
        guard let url else {
            cancelPreparation()
            return
        }

        let newRequest = Request(songID: songID, url: url)
        if cachedArtwork?.request == newRequest {
            if request != newRequest {
                task?.cancel()
                task = nil
                request = nil
            }
            failedRequest = nil
            failedRequestDate = nil
            return
        }
        guard canAttempt(newRequest),
              request != newRequest || task == nil else {
            return
        }

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
                        Self.preferredPixelSize
                )
                try Task.checkCancellation()

                let jpegData = await Task.detached(
                    priority: .utility
                ) {
                    ArtworkThumbnailEncoder.jpegData(
                        from: sourceData,
                        maximumPixelSize:
                            Self.preferredPixelSize
                    )
                }.value
                try Task.checkCancellation()
                guard let jpegData else {
                    throw URLError(
                        .cannotDecodeContentData
                    )
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
                    "Prepared notification artwork (\(jpegData.count, privacy: .public) bytes)"
                )
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
                    "Failed to prepare notification artwork: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func attachment(
        songID: Int,
        url: URL?
    ) async -> UNNotificationAttachment? {
        guard let url else {
            return nil
        }

        let expectedRequest = Request(
            songID: songID,
            url: url
        )
        prepare(songID: songID, url: url)

        if request == expectedRequest,
           let task {
            await task.value
        }
        guard !Task.isCancelled,
              let cachedArtwork,
              cachedArtwork.request == expectedRequest else {
            return nil
        }

        do {
            return try attachmentStager.makeAttachment(
                from: cachedArtwork.data
            )
        } catch {
            if self.cachedArtwork?.request
                == expectedRequest {
                self.cachedArtwork = nil
            }
            failedRequest = expectedRequest
            failedRequestDate = .now
            Self.logger.error(
                "Failed to create notification attachment: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    func cancelPreparation() {
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
}
