import SwiftUI

struct LyricsLiveActivitySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var settings = settings
        let preferences = LyricsLiveActivityPreferences(
            settings: settings
        )

        Form {
            Section {
                Label(
                    "ui.settings.live_activity.warning.title",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(.orange)

                Text("ui.settings.live_activity.warning.footer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("ui.settings.live_activity.status.section")
            }

            Section {
                LabeledContent("ui.settings.system_lyrics.title_format") {
                    formatField(
                        L10n.string("ui.settings.system_lyrics.title_format"),
                        text: $settings.lyricsLiveActivityTitleFormat
                    )
                }

                LabeledContent("ui.settings.system_lyrics.subtitle_format") {
                    formatField(
                        L10n.string("ui.settings.system_lyrics.subtitle_format"),
                        text:
                            $settings
                                .lyricsLiveActivitySubtitleFormat
                    )
                }

                LabeledContent("ui.settings.live_activity.compact_format") {
                    formatField(
                        L10n.string("ui.settings.live_activity.compact_format"),
                        text:
                            $settings
                                .lyricsLiveActivityCompactFormat
                    )
                }
            } header: {
                Text("ui.settings.lyrics_format.section")
            } footer: {
                Text("ui.settings.live_activity.format.footer")
            }

            Section {
                Toggle(
                    "ui.settings.live_activity.show_artwork",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsArtwork
                )

                Picker(
                    "ui.settings.live_activity.text_size",
                    selection:
                        $settings
                            .lyricsLiveActivityCompactTextSize
                ) {
                    ForEach(
                        LyricsLiveActivityCompactTextSize.allCases
                    ) { size in
                        Text(size.title).tag(size)
                    }
                }

                Toggle(
                    "ui.settings.live_activity.auto_scroll",
                    isOn:
                        $settings
                            .lyricsLiveActivityScrollsCompactText
                )

                if settings.lyricsLiveActivityScrollsCompactText {
                    valueSlider(
                        title: L10n.string("ui.settings.live_activity.scroll_speed"),
                        value:
                            $settings
                                .lyricsLiveActivityScrollSpeed,
                        range:
                            AppSettings
                                .lyricsLiveActivityScrollSpeedRange,
                        step: 1,
                        valueText:
                            L10n.format(
                                "ui.settings.live_activity.points_per_second",
                                Int(settings.lyricsLiveActivityScrollSpeed.rounded())
                            )
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.live_activity.start_pause"),
                        value:
                            $settings
                                .lyricsLiveActivityScrollPause,
                        range:
                            AppSettings
                                .lyricsLiveActivityScrollPauseRange,
                        step: 0.1,
                        valueText: L10n.format(
                            "ui.common.seconds_decimal",
                            settings.lyricsLiveActivityScrollPause
                        )
                    )
                }
            } header: {
                Text("ui.settings.live_activity.compact.section")
            } footer: {
                Text("ui.settings.live_activity.compact.footer")
            }

            Section {
                Toggle(
                    "ui.settings.live_activity.show_next",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsNextLyric
                )
                Toggle(
                    "ui.settings.live_activity.show_progress",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsProgress
                )
            } header: {
                Text("ui.settings.live_activity.expanded.section")
            }
        }
        .navigationTitle("ui.settings.live_activity.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preferences) {
            player.applyLyricsLiveActivityPreference()
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
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}

private extension LyricsLiveActivityCompactTextSize {
    var title: String {
        switch self {
        case .small: L10n.string("ui.common.size.small")
        case .standard: L10n.string("ui.common.size.standard")
        case .large: L10n.string("ui.common.size.large")
        }
    }
}
