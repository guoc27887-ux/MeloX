import SwiftUI

enum PlayerSettingsResetter {
    @MainActor
    static func reset(
        settings: AppSettings,
        player: PlayerStore
    ) async {
        await Task.yield()

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            settings.resetPlayerSettings()
        }

        await Task.yield()
        player.resetAutoMixPreference()
        player.applyVolumeControlMode()
        player.applyEqualizerSettings()
        player.applyAutoMixSettings()
        player.applySystemNowPlayingLyricsPreference()
        player.applyLyricsLiveActivityPreference()
        player.applyLyricsNotificationPreference()
    }
}
