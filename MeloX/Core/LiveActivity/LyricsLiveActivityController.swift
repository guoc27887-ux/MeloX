import ActivityKit
import Foundation
import OSLog

struct LyricsLiveActivitySnapshot: Equatable {
    let songID: Int
    let title: String
    let subtitle: String
    let compactText: String
    let compactScrollDistance: Double
    let nextLyric: String?
    let artworkURL: URL?
    let presentation: LyricsLiveActivityPresentation
    let isPlaying: Bool
    let playbackPosition: TimeInterval
    let duration: TimeInterval
    let staleDate: Date?

    func contentState(
        artworkData: Data?
    ) -> LyricsLiveActivityAttributes.ContentState {
        let safeDuration = max(duration, 0)
        let safePosition = safeDuration > 0
            ? min(max(playbackPosition, 0), safeDuration)
            : max(playbackPosition, 0)
        let safeCompactText = limited(compactText)
        let safeCompactScrollDistance = min(
            max(compactScrollDistance, 0),
            LyricsLiveActivityCompactLayout
                .scrollDistanceToRevealEnd(
                    text: safeCompactText,
                    pointSize:
                        presentation.compactTextSize.pointSize
                )
        )
        return LyricsLiveActivityAttributes.ContentState(
            title: limited(title),
            subtitle: limited(subtitle),
            compactText: safeCompactText,
            compactScrollOffset:
                LyricsLiveActivityCompactLayout.characterOffset(
                    text: safeCompactText,
                    pointSize:
                        presentation.compactTextSize.pointSize,
                    travelDistance: safeCompactScrollDistance
                ),
            compactScrollDistance: safeCompactScrollDistance,
            nextLyric: nextLyric.map(limited),
            artworkData: artworkData,
            presentation: presentation,
            isPlaying: isPlaying,
            playbackPosition: safePosition,
            duration: safeDuration,
            updatedAt: .now
        )
    }

    private func limited(_ value: String) -> String {
        String(
            value.prefix(
                LyricsLiveActivityArtworkPolicy
                    .maximumTextCharacterCount
            )
        )
    }
}

@MainActor
final class LyricsLiveActivityController {
    private static let failedRequestRetryInterval: TimeInterval = 10
    private static let logger = Logger(
        subsystem: "moye.MeloX",
        category: "LyricsLiveActivity"
    )

    private enum PendingCommand {
        case synchronize(LyricsLiveActivitySnapshot?)
    }

    private var currentActivity:
        Activity<LyricsLiveActivityAttributes>?
    private var pendingCommand: PendingCommand?
    private var isSynchronizing = false
    private var lastFailedRequestDate: Date?
    private var latestSnapshot: LyricsLiveActivitySnapshot?
    private let artworkStore = LyricsLiveActivityArtworkStore()

    init() {
        currentActivity =
            Activity<LyricsLiveActivityAttributes>.activities.first
    }

    func synchronize(with snapshot: LyricsLiveActivitySnapshot?) {
        latestSnapshot = snapshot
        pendingCommand = .synchronize(snapshot)
        guard !isSynchronizing else { return }

        isSynchronizing = true
        Task { @MainActor [weak self] in
            await self?.drainPendingCommands()
        }
    }

    private func drainPendingCommands() async {
        while let command = pendingCommand {
            pendingCommand = nil
            switch command {
            case .synchronize(let snapshot):
                await apply(snapshot)
            }
        }
        isSynchronizing = false
    }

    private func apply(
        _ snapshot: LyricsLiveActivitySnapshot?
    ) async {
        guard let snapshot else {
            await endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.logger.notice(
                "Live Activities are disabled by system authorization"
            )
            return
        }

        let artworkData = snapshot.presentation.showsArtwork
            ? artworkStore.cachedData(
                songID: snapshot.songID,
                url: snapshot.artworkURL
            )
            : nil
        let content = ActivityContent(
            state: snapshot.contentState(
                artworkData: artworkData
            ),
            staleDate: snapshot.staleDate,
            relevanceScore: 100
        )
        let allActivities = Activity<
            LyricsLiveActivityAttributes
        >.activities
        let activities = allActivities.filter(isUsable)
        for obsoleteActivity in allActivities
        where !isUsable(obsoleteActivity) {
            await obsoleteActivity.end(
                nil,
                dismissalPolicy: .immediate
            )
        }

        if let activity = activities.first
            ?? usableCurrentActivity {
            currentActivity = activity
            lastFailedRequestDate = nil
            await activity.update(content)
            guard isUsable(activity) else {
                currentActivity = nil
                await requestActivity(
                    content: content,
                    snapshot: snapshot,
                    artworkData: artworkData
                )
                return
            }

            for duplicate in activities.dropFirst() {
                await duplicate.end(
                    nil,
                    dismissalPolicy: .immediate
                )
            }
            prepareArtworkIfNeeded(
                for: snapshot,
                currentData: artworkData
            )
            return
        }

        currentActivity = nil
        await requestActivity(
            content: content,
            snapshot: snapshot,
            artworkData: artworkData
        )
    }

    private func requestActivity(
        content: ActivityContent<
            LyricsLiveActivityAttributes.ContentState
        >,
        snapshot: LyricsLiveActivitySnapshot,
        artworkData: Data?
    ) async {
        guard canAttemptActivityRequest() else { return }

        do {
            let activity = try Activity.request(
                attributes: LyricsLiveActivityAttributes(
                    sessionID: UUID(),
                    schemaVersion:
                        LyricsLiveActivityAttributes
                            .currentSchemaVersion
                ),
                content: content,
                pushType: nil,
                style: .standard
            )
            currentActivity = activity
            lastFailedRequestDate = nil
            Self.logger.notice(
                "Started Live Activity \(activity.id, privacy: .public)"
            )
            prepareArtworkIfNeeded(
                for: snapshot,
                currentData: artworkData
            )
        } catch {
            currentActivity = nil
            lastFailedRequestDate = .now
            Self.logger.error(
                "Failed to start Live Activity: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func prepareArtworkIfNeeded(
        for snapshot: LyricsLiveActivitySnapshot,
        currentData: Data?
    ) {
        guard snapshot.presentation.showsArtwork,
              currentData == nil else { return }
        artworkStore.prepare(
            songID: snapshot.songID,
            url: snapshot.artworkURL
        ) { [weak self] _ in
            guard let self,
                  let latestSnapshot = self.latestSnapshot,
                  latestSnapshot.songID == snapshot.songID,
                  latestSnapshot.artworkURL == snapshot.artworkURL
            else {
                return
            }
            self.synchronize(with: latestSnapshot)
        }
    }

    private func endAllActivities() async {
        let activities =
            Activity<LyricsLiveActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        lastFailedRequestDate = nil
        artworkStore.clear()
    }

    private func canAttemptActivityRequest(
        at date: Date = .now
    ) -> Bool {
        guard let lastFailedRequestDate else { return true }
        return date.timeIntervalSince(lastFailedRequestDate)
            >= Self.failedRequestRetryInterval
    }

    private var usableCurrentActivity:
        Activity<LyricsLiveActivityAttributes>? {
        guard let currentActivity else { return nil }
        return isUsable(currentActivity)
            ? currentActivity
            : nil
    }

    private func isUsable(
        _ activity: Activity<LyricsLiveActivityAttributes>
    ) -> Bool {
        guard activity.attributes.schemaVersion
                == LyricsLiveActivityAttributes
                    .currentSchemaVersion else {
            return false
        }
        switch activity.activityState {
        case .pending, .active, .stale:
            return true
        case .ended, .dismissed:
            return false
        @unknown default:
            return false
        }
    }
}
