import SwiftUI

struct WatchAudioSettingsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    @AppStorage(WatchPreferenceKey.streamingQuality)
    private var qualityRawValue = WatchStreamingQuality.high.rawValue

    var body: some View {
        Form {
            Section {
                Picker("ui.player.playback_quality", selection: $qualityRawValue) {
                    ForEach(WatchStreamingQuality.allCases) { quality in
                        Text(quality.title).tag(quality.rawValue)
                    }
                }
            } header: {
                Text("ui.watch.audio.streaming")
            } footer: {
                Text("ui.watch.audio.quality.footer")
            }

            Section("ui.player.volume") {
                LabeledContent(
                    "ui.watch.audio.current_volume",
                    value: coordinator.volume.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )

                Slider(
                    value: Binding(
                        get: { coordinator.volume },
                        set: { coordinator.setVolume($0) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("ui.player.volume")
            }
        }
        .navigationTitle("ui.watch.settings.audio")
        .onChange(of: qualityRawValue) {
            Task {
                await coordinator.reloadForSelectedQuality()
            }
        }
    }
}

struct WatchPlaybackBehaviorSettingsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    @AppStorage(WatchPreferenceKey.autoPlaySelection)
    private var autoPlaySelection = true
    @AppStorage(WatchPreferenceKey.previousButtonBehavior)
    private var previousBehaviorRawValue =
        WatchPreviousButtonBehavior.restartAfterFiveSeconds.rawValue
    @AppStorage(WatchPreferenceKey.restoresLastSession)
    private var restoresLastSession = true
    @AppStorage(WatchPreferenceKey.resumesAfterInterruption)
    private var resumesAfterInterruption = true

    var body: some View {
        Form {
            Section("ui.player.queue") {
                Picker(
                    "ui.watch.playback.repeat_mode",
                    selection: Binding(
                        get: { coordinator.repeatMode },
                        set: { coordinator.setRepeatMode($0) }
                    )
                ) {
                    ForEach(WatchRepeatMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle(
                    "ui.player.shuffle",
                    isOn: Binding(
                        get: { coordinator.isShuffled },
                        set: { coordinator.setShuffleEnabled($0) }
                    )
                )
            }

            Section("ui.watch.playback.actions") {
                Toggle("ui.watch.playback.auto_play_selection", isOn: $autoPlaySelection)

                Picker(
                    "ui.watch.playback.previous_button",
                    selection: $previousBehaviorRawValue
                ) {
                    ForEach(WatchPreviousButtonBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior.rawValue)
                    }
                }
            }

            Section {
                Toggle("ui.watch.playback.restore_session", isOn: $restoresLastSession)
                Toggle("ui.watch.playback.resume_interruption", isOn: $resumesAfterInterruption)
            } header: {
                Text("ui.watch.playback.restore")
            } footer: {
                Text("ui.watch.playback.restore.footer")
            }
        }
        .navigationTitle("ui.watch.settings.playback_behavior")
        .onChange(of: restoresLastSession) { _, isEnabled in
            coordinator.setRestoresLastSession(isEnabled)
        }
    }
}
