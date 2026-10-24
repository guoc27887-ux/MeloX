import SwiftUI

struct LyricsInteractionSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    settings.lyricsStyle == .appleMusic
                        ? L10n.string("ui.settings.lyrics.interaction.tap_to_seek")
                        : L10n.string("ui.settings.lyrics.interaction.double_tap_to_seek"),
                    isOn: $settings.lyricsTapToSeek
                )

                if settings.lyricsStyle == .appleMusic {
                    Toggle(
                        "ui.settings.lyrics.interaction.long_press_share",
                        isOn: $settings.lyricsLongPressToShare
                    )
                }

                Toggle(
                    "ui.settings.lyrics.interaction.auto_follow",
                    isOn: $settings.lyricsAutoFollow
                )

                if settings.lyricsAutoFollow {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.interaction.follow_delay"),
                        value: $settings.lyricsFollowDelay,
                        range: 1...10,
                        step: 1,
                        valueText: L10n.format("ui.common.seconds", Int(settings.lyricsFollowDelay))
                    )
                }
            } header: {
                Text("ui.settings.lyrics.interaction.section.browse_seek")
            } footer: {
                Text("ui.settings.lyrics.interaction.auto_follow.footer")
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.lyrics.interaction.advance_time"),
                    value: $settings.lyricsAdvanceTime,
                    range: 0...5,
                    step: 0.1,
                    valueText:
                        L10n.format("ui.common.seconds_decimal", settings.lyricsAdvanceTime)
                )

                Toggle(
                    "ui.settings.lyrics.interaction.advance_word_by_word",
                    isOn:
                        $settings
                            .lyricsAdvanceTimeAppliesToWordByWord
                )
            } header: {
                Text("ui.settings.lyrics.interaction.section.sync")
            } footer: {
                Text("ui.settings.lyrics.interaction.sync.footer")
            }

            if settings.lyricsStyle == .appleMusic {
                Section {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.interaction.controls_auto_hide"),
                        value:
                            $settings
                                .appleMusicLyricsInterfaceAutoHideDelay,
                        range:
                            AppSettings
                                .appleMusicLyricsInterfaceAutoHideDelayRange,
                        step: 1,
                        valueText:
                            L10n.format("ui.common.seconds", Int(settings.appleMusicLyricsInterfaceAutoHideDelay))
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.interaction.scroll_hide_threshold"),
                        value:
                            $settings
                                .appleMusicLyricsScrollHideThreshold,
                        range:
                            AppSettings
                                .appleMusicLyricsScrollHideThresholdRange,
                        step: 10,
                        valueText:
                            L10n.format("ui.common.points", Int(settings.appleMusicLyricsScrollHideThreshold))
                    )
                } header: {
                    Text("ui.settings.lyrics.interaction.section.apple_music_interface")
                } footer: {
                    Text("ui.settings.lyrics.interaction.apple_music.footer")
                }
            }
        }
        .navigationTitle("ui.settings.lyrics.interaction.title")
        .navigationBarTitleDisplayMode(.inline)
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
