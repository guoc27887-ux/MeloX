import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("ui.settings.playback.wifi_quality", selection: qualityBinding) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker(
                    "ui.settings.playback.cellular_quality",
                    selection: $settings.cellularQuality
                ) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker(
                    "ui.settings.playback.volume_control",
                    selection: $settings.playerVolumeControlMode
                ) {
                    ForEach(PlayerVolumeControlMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("ui.settings.playback.section.playback")
            } footer: {
                Text(
                    L10n.format(
                        "ui.settings.playback.quality.footer",
                        settings.playerVolumeControlMode.description
                    )
                )
            }

            Section {
                NavigationLink {
                    EqualizerSettingsView()
                } label: {
                    LabeledContent(
                        L10n.string("ui.settings.equalizer.title"),
                        value: settings.equalizer.summary
                    )
                }

                NavigationLink {
                    AutoMixSettingsView()
                } label: {
                    LabeledContent(
                        L10n.string("ui.settings.automix.title"),
                        value: player.isAutoMixEnabled
                            ? settings.autoMix.mode.title
                            : L10n.string("ui.common.off")
                    )
                }
            } header: {
                Text("ui.settings.playback.section.audio_processing")
            } footer: {
                Text(
                    AppFeatureAvailability.downloads
                        ? L10n.string("ui.settings.playback.audio_processing.footer.downloads")
                        : L10n.string("ui.settings.playback.audio_processing.footer")
                )
            }

            Section {
                Toggle(
                    "ui.settings.playback.start_heart_mode",
                    isOn: $settings.startsHeartModeOnLaunch
                )

                Toggle(
                    "ui.settings.playback.remember_page",
                    isOn: $settings.rememberNowPlayingPage
                )

                Toggle(
                    "ui.settings.playback.previous_restarts",
                    isOn: $settings.previousRestartsCurrentSong
                )
            } header: {
                Text("ui.settings.playback.section.behavior")
            } footer: {
                Text(
                    "ui.settings.playback.behavior.footer"
                )
            }

            Section {
                Toggle(
                    "ui.settings.playback.gray_unblock",
                    isOn: $settings.grayTrackUnblockEnabled
                )

                if settings.grayTrackUnblockEnabled {
                    ForEach(GrayTrackSource.allCases, id: \.self) { source in
                        Toggle(
                            isOn: Binding(
                                get: { settings.enabledUnblockSources.contains(source) },
                                set: { isEnabled in
                                    if isEnabled {
                                        settings.enabledUnblockSources.insert(source)
                                    } else {
                                        settings.enabledUnblockSources.remove(source)
                                    }
                                }
                            )
                        ) {
                            Text(verbatim: source.displayName)
                        }
                    }
                }
            } header: {
                Text("ui.settings.playback.gray_unblock.sources")
            } footer: {
                Text("ui.settings.playback.gray_unblock.footer")
            }
        }
        .navigationTitle("ui.settings.playback.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.playerVolumeControlMode) {
            player.applyVolumeControlMode()
        }
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: { settings.quality },
            set: { player.selectPlaybackQuality($0) }
        )
    }
}
