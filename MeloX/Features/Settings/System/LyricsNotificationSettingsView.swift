import SwiftUI
import UIKit

struct LyricsNotificationSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(LyricsNotificationController.self)
    private var notifications
    @Environment(\.openURL) private var openURL

    private var permissionStatus:
        LyricsNotificationAuthorizationStatus
    {
        notifications.authorizationStatus
    }

    var body: some View {
        @Bindable var preferences =
            settings.lyricsNotifications
        let deliveryPreferences =
            LyricsNotificationDeliveryPreferences(
                preferences: preferences
            )
        let contentPreferences =
            LyricsNotificationContentPreferences(
                preferences: preferences
            )

        Form {
            Section {
                LabeledContent("ui.settings.lyrics_notification.permission") {
                    Label(
                        permissionStatus.title,
                        systemImage:
                            permissionStatus.systemImage
                    )
                    .foregroundStyle(
                        permissionStatus == .denied
                            ? .red
                            : .secondary
                    )
                }

                if permissionStatus == .denied {
                    Button(
                        "ui.settings.lyrics_notification.open_settings",
                        systemImage: "gear"
                    ) {
                        openNotificationSettings()
                    }
                }
            } header: {
                Text("ui.settings.lyrics_notification.permission.section")
            } footer: {
                Text("ui.settings.lyrics_notification.permission.footer")
            }

            Section {
                LabeledContent("ui.settings.system_lyrics.title_format") {
                    formatField(
                        L10n.string("ui.settings.system_lyrics.title_format"),
                        text: $preferences.titleFormat
                    )
                }

                Toggle(
                    "ui.settings.lyrics_notification.show_subtitle",
                    isOn: $preferences.showsSubtitle
                )

                if preferences.showsSubtitle {
                    LabeledContent("ui.settings.system_lyrics.subtitle_format") {
                        formatField(
                            L10n.string("ui.settings.system_lyrics.subtitle_format"),
                            text:
                                $preferences.subtitleFormat
                        )
                    }
                }

                Toggle(
                    "ui.settings.lyrics_notification.show_artwork",
                    isOn: $preferences.showsArtwork
                )

                Picker(
                    "ui.settings.lyrics_notification.body_content",
                    selection:
                        $preferences.supplementaryContent
                ) {
                    ForEach(
                        LyricsNotificationSupplementaryContent
                            .allCases
                    ) { content in
                        Text(content.title).tag(content)
                    }
                }

                Toggle(
                    "ui.settings.lyrics_notification.fallback_song_info",
                    isOn:
                        $preferences
                            .showsTrackInfoWhenLyricsUnavailable
                )
            } header: {
                Text("ui.settings.lyrics_notification.content.section")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ui.settings.lyrics_notification.content.format_footer")
                    Text("ui.settings.lyrics_notification.content.artwork_footer")
                }
            }

            Section {
                Toggle(
                    "ui.settings.lyrics_notification.show_foreground",
                    isOn:
                        $preferences.showsInForeground
                )

                Toggle(
                    "ui.settings.lyrics_notification.show_background",
                    isOn:
                        $preferences.showsInBackground
                )

                if !preferences.showsInForeground
                    && !preferences.showsInBackground {
                    Label(
                        "ui.settings.lyrics_notification.no_scene.warning",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("ui.settings.lyrics_notification.scene.section")
            }

            Section {
                Toggle(
                    "ui.settings.lyrics_notification.dismiss_on_pause",
                    isOn:
                        $preferences.removesWhenPaused
                )
            } header: {
                Text("ui.settings.lyrics_notification.behavior.section")
            } footer: {
                Text("ui.settings.lyrics_notification.behavior.footer")
            }

            Section {
                Button(
                    "ui.settings.lyrics_notification.send_test",
                    systemImage: "bell.badge"
                ) {
                    presentPreview()
                }
                .disabled(
                    notifications.isRequestingAuthorization
                )
            } footer: {
                if let error =
                    notifications.lastErrorDescription {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Text("ui.settings.lyrics_notification.test.footer")
                }
            }
        }
        .navigationTitle("ui.settings.lyrics_notification.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: deliveryPreferences) {
            player.refreshLyricsNotification()
        }
        .onChange(of: contentPreferences) {
            player.applyLyricsNotificationPreference()
        }
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
            .submitLabel(.done)
            .onSubmit {
                player.applyLyricsNotificationPreference()
            }
    }

    private func presentPreview() {
        Task { @MainActor in
            guard await notifications
                .requestAuthorization() else {
                return
            }
            player.presentLyricsNotificationPreview()
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
}

private struct LyricsNotificationContentPreferences:
    Equatable
{
    let showsSubtitle: Bool
    let showsArtwork: Bool
    let supplementaryContent:
        LyricsNotificationSupplementaryContent

    init(preferences: LyricsNotificationPreferences) {
        showsSubtitle = preferences.showsSubtitle
        showsArtwork = preferences.showsArtwork
        supplementaryContent =
            preferences.supplementaryContent
    }
}

private struct LyricsNotificationDeliveryPreferences:
    Equatable
{
    let showsTrackInfoWhenLyricsUnavailable: Bool
    let showsInForeground: Bool
    let showsInBackground: Bool
    let removesWhenPaused: Bool

    init(preferences: LyricsNotificationPreferences) {
        showsTrackInfoWhenLyricsUnavailable =
            preferences.showsTrackInfoWhenLyricsUnavailable
        showsInForeground =
            preferences.showsInForeground
        showsInBackground =
            preferences.showsInBackground
        removesWhenPaused =
            preferences.removesWhenPaused
    }
}

private extension LyricsNotificationAuthorizationStatus {
    var title: String {
        switch self {
        case .notDetermined:
            L10n.string("ui.settings.notification_status.not_determined")
        case .denied:
            L10n.string("ui.settings.notification_status.denied")
        case .authorized:
            L10n.string("ui.settings.notification_status.authorized")
        case .provisional:
            L10n.string("ui.settings.notification_status.provisional")
        case .ephemeral:
            L10n.string("ui.settings.notification_status.ephemeral")
        }
    }

    var systemImage: String {
        switch self {
        case .notDetermined:
            "questionmark.circle"
        case .denied:
            "bell.slash"
        case .authorized, .provisional, .ephemeral:
            "checkmark.circle"
        }
    }
}
