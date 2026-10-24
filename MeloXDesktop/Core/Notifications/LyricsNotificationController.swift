import AppKit
import Foundation
import Observation
import UserNotifications

private enum LyricsNotificationPendingAction {
    case publish(LyricsNotificationPublication)
    case clear
}

@MainActor
@Observable
final class LyricsNotificationController {
    private(set) var authorizationStatus:
        LyricsNotificationAuthorizationStatus = .notDetermined
    private(set) var isRequestingAuthorization = false
    private(set) var lastErrorDescription: String?

    @ObservationIgnored
    private let preferences: LyricsNotificationPreferences

    @ObservationIgnored
    private let notificationCenter: UNUserNotificationCenter

    @ObservationIgnored
    private let notificationDelegate:
        LyricsNotificationCenterDelegate

    @ObservationIgnored
    private let artworkStore =
        LyricsNotificationArtworkStore()

    @ObservationIgnored
    private var pendingAction:
        LyricsNotificationPendingAction?

    @ObservationIgnored
    private var publicationWorker: Task<Void, Never>?

    @ObservationIgnored
    private var lastPublicationKey:
        LyricsNotificationPublicationKey?

    @ObservationIgnored
    private var isSynchronizedAsCleared = false

    init(
        preferences: LyricsNotificationPreferences,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        let notificationDelegate =
            LyricsNotificationCenterDelegate()
        self.notificationDelegate = notificationDelegate
        notificationCenter.delegate = notificationDelegate
    }

    deinit {
        publicationWorker?.cancel()
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter
            .notificationSettings()
        authorizationStatus =
            LyricsNotificationAuthorizationStatus(
                settings.authorizationStatus
            )
    }

    func requestAuthorization() async -> Bool {
        guard !isRequestingAuthorization else {
            return authorizationStatus.allowsNotifications
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            do {
                _ = try await notificationCenter
                    .requestAuthorization(options: [.alert])
                lastErrorDescription = nil
            } catch {
                lastErrorDescription = error.localizedDescription
            }
            await refreshAuthorizationStatus()
        }
        return authorizationStatus.allowsNotifications
    }

    func update(
        song: Song?,
        lyrics: [LyricLine],
        playbackTime: TimeInterval,
        isPlaying: Bool,
        force: Bool = false
    ) {
        notificationDelegate.foregroundPresentationEnabled =
            preferences.showsInForeground

        guard preferences.isEnabled,
              let song else {
            artworkStore.cancelPreparation()
            clear()
            return
        }

        if preferences.showsArtwork {
            artworkStore.prepare(
                songID: song.id,
                url: song.album?.artworkURL
            )
        } else {
            artworkStore.cancelPreparation()
        }

        guard shouldPresentForCurrentApplicationState else {
            clear()
            return
        }

        if !isPlaying {
            if preferences.removesWhenPaused
                || lastPublicationKey?.songID != song.id {
                clear()
            }
            return
        }

        guard let publication =
            LyricsNotificationPublicationFactory.current(
                song: song,
                lyrics: lyrics,
                playbackTime: playbackTime,
                preferences: preferences
            ) else {
            clear()
            return
        }
        guard force
                || publication.key != lastPublicationKey else {
            return
        }

        lastPublicationKey = publication.key
        schedule(publication)
    }

    func presentPreview(
        song: Song?,
        lyrics: [LyricLine],
        playbackTime: TimeInterval
    ) {
        notificationDelegate.foregroundPresentationEnabled =
            preferences.showsInForeground
        if preferences.showsArtwork,
           let song {
            artworkStore.prepare(
                songID: song.id,
                url: song.album?.artworkURL
            )
        }
        let publication =
            LyricsNotificationPublicationFactory.preview(
                song: song,
                lyrics: lyrics,
                playbackTime: playbackTime,
                preferences: preferences
            )
        lastPublicationKey = publication.key
        schedule(publication)
    }

    func clear() {
        lastPublicationKey = nil
        if publicationWorker != nil {
            pendingAction = .clear
        }
        guard !isSynchronizedAsCleared
                || publicationWorker != nil else {
            return
        }
        isSynchronizedAsCleared = true
        removeCurrentNotification()
    }

    private var shouldPresentForCurrentApplicationState: Bool {
        NSApplication.shared.isActive
            ? preferences.showsInForeground
            : preferences.showsInBackground
    }

    private func schedule(
        _ publication: LyricsNotificationPublication
    ) {
        pendingAction = .publish(publication)
        isSynchronizedAsCleared = false
        removeCurrentNotification()

        guard publicationWorker == nil else { return }
        publicationWorker = Task { [weak self] in
            await self?.processPendingPublications()
        }
    }

    private func processPendingPublications() async {
        while !Task.isCancelled,
              let action = pendingAction {
            pendingAction = nil
            guard case let .publish(publication) = action else {
                removeCurrentNotification()
                isSynchronizedAsCleared = true
                continue
            }

            let settings = await notificationCenter
                .notificationSettings()
            authorizationStatus =
                LyricsNotificationAuthorizationStatus(
                    settings.authorizationStatus
                )

            guard pendingAction == nil else { continue }
            guard authorizationStatus.allowsNotifications else {
                handlePublicationFailure(
                    publication,
                    errorDescription: nil
                )
                continue
            }

            do {
                let request = await request(
                    for: publication
                )
                guard pendingAction == nil else {
                    continue
                }
                try await notificationCenter.add(
                    request
                )
                isSynchronizedAsCleared = false
                lastErrorDescription = nil
            } catch {
                handlePublicationFailure(
                    publication,
                    errorDescription:
                        error.localizedDescription
                )
            }
        }

        publicationWorker = nil
        if pendingAction != nil {
            publicationWorker = Task { [weak self] in
                await self?.processPendingPublications()
            }
        }
    }

    private func request(
        for publication: LyricsNotificationPublication
    ) async -> UNNotificationRequest {
        removeCurrentNotification()

        let content = UNMutableNotificationContent()
        content.title = publication.text.title
        content.subtitle = publication.text.subtitle
        content.body = publication.text.body
        content.threadIdentifier =
            LyricsNotificationConstants.notificationThreadID
        content.targetContentIdentifier =
            LyricsNotificationConstants.notificationID
        content.interruptionLevel = .active
        content.relevanceScore = 1
        content.userInfo = [
            LyricsNotificationConstants.lyricsMarkerKey: true,
            LyricsNotificationConstants.previewMarkerKey:
                publication.isPreview,
        ]
        if let attachment = await artworkStore.attachment(
            songID: publication.key.songID,
            url: publication.artworkURL
        ) {
            content.attachments = [attachment]
        }

        return UNNotificationRequest(
            identifier:
                LyricsNotificationConstants.notificationID,
            content: content,
            trigger: nil
        )
    }

    private func handlePublicationFailure(
        _ publication: LyricsNotificationPublication,
        errorDescription: String?
    ) {
        if lastPublicationKey == publication.key {
            lastPublicationKey = nil
        }
        isSynchronizedAsCleared = true
        lastErrorDescription = errorDescription
        removeCurrentNotification()
    }

    private func removeCurrentNotification() {
        let identifiers = [
            LyricsNotificationConstants.notificationID
        ]
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: identifiers
        )
    }
}
