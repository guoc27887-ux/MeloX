import Foundation
import OSLog
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class LyricsNotificationAttachmentStager {
    private static let stagedAttachmentLifetime: TimeInterval =
        60 * 60
    private static let maximumStagedAttachmentCount = 8
    private static let logger = Logger(
        subsystem: "moye.MeloX",
        category: "LyricsNotificationAttachment"
    )

    init() {
        removeLegacyDiskCache()
        cleanStagedAttachments()
    }

    func makeAttachment(
        from data: Data
    ) throws -> UNNotificationAttachment {
        cleanStagedAttachments(reservingNewAttachment: true)
        let attachmentURL = try stage(data)
        do {
            return try UNNotificationAttachment(
                identifier:
                    LyricsNotificationConstants.artworkAttachmentID,
                url: attachmentURL,
                options: [
                    UNNotificationAttachmentOptionsTypeHintKey:
                        UTType.jpeg.identifier,
                    UNNotificationAttachmentOptionsThumbnailHiddenKey:
                        false,
                ]
            )
        } catch {
            try? FileManager.default.removeItem(at: attachmentURL)
            throw error
        }
    }

    private func stage(_ data: Data) throws -> URL {
        let directory = stagedAttachmentDirectoryURL
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let destination = directory.appending(
            path: "\(UUID().uuidString).jpg",
            directoryHint: .notDirectory
        )
        try data.write(
            to: destination,
            options: [
                .atomic,
                .completeFileProtectionUntilFirstUserAuthentication,
            ]
        )
        return destination
    }

    private var stagedAttachmentDirectoryURL: URL {
        AppStorageLocations
            .lyricsNotificationAttachmentDirectory()
    }

    private func cleanStagedAttachments(
        reservingNewAttachment: Bool = false,
        at date: Date = .now
    ) {
        let directory = stagedAttachmentDirectoryURL
        guard let files =
            try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey,
                ],
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }

        let candidates = files.compactMap {
            file -> (url: URL, modifiedAt: Date)? in
            guard let values = try? file.resourceValues(
                forKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey,
                ]
            ),
                values.isRegularFile == true else {
                return nil
            }
            return (
                file,
                values.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }

        let expirationDate = date.addingTimeInterval(
            -Self.stagedAttachmentLifetime
        )
        let retainedCount = max(
            Self.maximumStagedAttachmentCount
                - (reservingNewAttachment ? 1 : 0),
            0
        )
        for (index, candidate) in candidates.enumerated()
        where index >= retainedCount
            || candidate.modifiedAt < expirationDate {
            try? FileManager.default.removeItem(
                at: candidate.url
            )
        }
    }

    private func removeLegacyDiskCache() {
        guard let directory =
            AppStorageLocations
                .legacyLyricsNotificationArtworkDirectory() else {
            return
        }
        guard FileManager.default.fileExists(
            atPath: directory.path
        ) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Self.logger.error(
                "Failed to remove legacy notification artwork cache: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
