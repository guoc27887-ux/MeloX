import SwiftUI
import UIKit

struct SystemPlaybackSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(LyricsNotificationController.self)
    private var notifications
    @Environment(\.openURL) private var openURL

    @State private var showsNotificationPermissionAlert =
        false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "ui.settings.system_lyrics.enabled",
                    isOn: $settings.systemNowPlayingLyricsEnabled
                )

                if settings.systemNowPlayingLyricsEnabled {
                    LabeledContent("ui.settings.system_lyrics.title_format") {
                        formatField(
                            L10n.string("ui.settings.system_lyrics.title_format"),
                            text:
                                $settings
                                    .systemNowPlayingLyricsTitleFormat
                        )
                    }

                    LabeledContent("ui.settings.system_lyrics.subtitle_format") {
                        formatField(
                            L10n.string("ui.settings.system_lyrics.subtitle_format"),
                            text:
                                $settings
                                    .systemNowPlayingLyricsSubtitleFormat
                        )
                    }
                }
            } header: {
                Text("ui.settings.system_lyrics.now_playing.section")
            } footer: {
                Text("ui.settings.system_lyrics.now_playing.footer")
            }

            Section {
                Toggle(
                    "ui.settings.lyrics_notification.title",
                    isOn: lyricsNotificationEnabledBinding
                )
                .disabled(
                    notifications.isRequestingAuthorization
                )

                if settings.lyricsNotifications.isEnabled {
                    NavigationLink {
                        LyricsNotificationSettingsView()
                    } label: {
                        Label(
                            "ui.settings.lyrics_notification.settings",
                            systemImage: "bell.badge"
                        )
                    }

                    if notifications.authorizationStatus
                        == .denied {
                        Label(
                            "ui.settings.lyrics_notification.permission_disabled",
                            systemImage: "bell.slash.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("ui.settings.lyrics_notification.title")
            } footer: {
                Text("ui.settings.lyrics_notification.summary")
            }

            Section {
                Toggle(
                    "ui.settings.live_activity.enabled_experimental",
                    isOn: $settings.lyricsLiveActivityEnabled
                )

                if settings.lyricsLiveActivityEnabled {
                    NavigationLink {
                        LyricsLiveActivitySettingsView()
                    } label: {
                        Label(
                            "ui.settings.live_activity.settings",
                            systemImage: "waveform.and.magnifyingglass"
                        )
                    }
                }
            } header: {
                Text("ui.settings.live_activity.section")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "ui.settings.live_activity.warning.title",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)

                    Text("ui.settings.live_activity.warning.system_footer")
                }
            }

            Section {
                Text("ui.settings.lyrics_format.footer")
                    .foregroundStyle(.secondary)
            } header: {
                Text("ui.settings.lyrics_format.section")
            }
        }
        .navigationTitle("ui.settings.catalog.system_lyrics.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: settings.systemNowPlayingLyricsEnabled) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsTitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsSubtitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.lyricsLiveActivityEnabled) {
            player.applyLyricsLiveActivityPreference()
        }
        .alert(
            "ui.settings.lyrics_notification.enable_failed.title",
            isPresented:
                $showsNotificationPermissionAlert
        ) {
            Button("ui.common.open_system_settings") {
                openNotificationSettings()
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: {
            Text("ui.settings.lyrics_notification.permission_required")
        }
    }

    private var lyricsNotificationEnabledBinding:
        Binding<Bool>
    {
        Binding {
            settings.lyricsNotifications.isEnabled
        } set: { isEnabled in
            if !isEnabled {
                settings.lyricsNotifications.isEnabled = false
                player.applyLyricsNotificationPreference()
                return
            }

            Task { @MainActor in
                guard await notifications
                    .requestAuthorization() else {
                    settings.lyricsNotifications.isEnabled =
                        false
                    showsNotificationPermissionAlert = true
                    return
                }
                settings.lyricsNotifications.isEnabled = true
                player.applyLyricsNotificationPreference()
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string:
                UIApplication
                    .openNotificationSettingsURLString
        ) else {
            return
        }
        openURL(url)
    }

    private func formatField(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        TextField(title, text: text)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
