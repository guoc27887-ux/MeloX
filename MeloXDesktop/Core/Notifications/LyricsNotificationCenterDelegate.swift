import Foundation
import UserNotifications

enum LyricsNotificationConstants {
    nonisolated static let notificationID =
        "melox.lyrics.current"
    nonisolated static let notificationThreadID =
        "melox.lyrics"
    nonisolated static let artworkAttachmentID =
        "melox.lyrics.artwork"
    nonisolated static let lyricsMarkerKey =
        "meloxLyricsNotification"
    nonisolated static let previewMarkerKey =
        "meloxLyricsNotificationPreview"
}

@MainActor
final class LyricsNotificationCenterDelegate:
    NSObject,
    UNUserNotificationCenterDelegate
{
    var foregroundPresentationEnabled = true

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        guard userInfo[
            LyricsNotificationConstants.lyricsMarkerKey
        ] as? Bool == true else {
            return []
        }

        let isPreview = userInfo[
            LyricsNotificationConstants.previewMarkerKey
        ] as? Bool == true
        let shouldPresent = await MainActor.run {
            isPreview || foregroundPresentationEnabled
        }
        return shouldPresent ? [.banner, .list] : []
    }
}
