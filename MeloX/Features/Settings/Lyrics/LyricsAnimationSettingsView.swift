import SwiftUI

struct LyricsAnimationSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        @Bindable var appleMusicLyrics = settings.appleMusicLyrics

        Form {
            Section {
                Picker(
                    "ui.settings.lyrics.animation.refresh_rate",
                    selection: $settings.lyricsRefreshRate
                ) {
                    ForEach(LyricsRefreshRate.allCases) { refreshRate in
                        Text(refreshRate.title).tag(refreshRate)
                    }
                }
            } header: {
                Text("ui.settings.lyrics.animation.section.performance")
            } footer: {
                Text("ui.settings.lyrics.animation.performance.footer")
            }

            if settings.lyricsStyle == .appleMusic,
               appleMusicLyrics.motionPreset == .custom {
                Section {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.base_cascade_delay"),
                        value: $settings.lyricsFocusCascadeDelay,
                        range: AppSettings.lyricsFocusCascadeDelayRange,
                        step: 0.001,
                        valueText:
                            L10n.format("ui.common.milliseconds", Int((settings.lyricsFocusCascadeDelay * 1_000).rounded()))
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.cascade_increment"),
                        value: $settings.lyricsFocusCascadeDelayIncrease,
                        range:
                            AppSettings
                                .lyricsFocusCascadeDelayIncreaseRange,
                        step: 0.001,
                        valueText:
                            L10n.format("ui.common.milliseconds_per_line", Int((settings.lyricsFocusCascadeDelayIncrease * 1_000).rounded()))
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.following_delay"),
                        value: $settings.lyricsFocusCascadeFollowingDelay,
                        range:
                            AppSettings
                                .lyricsFocusCascadeFollowingDelayRange,
                        step: 0.001,
                        valueText:
                            L10n.format("ui.common.milliseconds", Int((settings.lyricsFocusCascadeFollowingDelay * 1_000).rounded()))
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.catch_up_ratio"),
                        value: $settings.lyricsFocusCascadeCatchUpRatio,
                        range:
                            AppSettings
                                .lyricsFocusCascadeCatchUpRatioRange,
                        step: 0.01,
                        valueText:
                            L10n.percent(settings.lyricsFocusCascadeCatchUpRatio)
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.chase_speed_gradient"),
                        value:
                            $settings
                                .lyricsFocusCascadeChaseSpeedGradient,
                        range:
                            AppSettings
                                .lyricsFocusCascadeChaseSpeedGradientRange,
                        step: 0.01,
                        valueText:
                            L10n.percent(settings.lyricsFocusCascadeChaseSpeedGradient)
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.settle_duration"),
                        value: $settings.lyricsFocusCascadeDuration,
                        range:
                            AppSettings
                                .lyricsFocusCascadeDurationRange,
                        step: 0.01,
                        valueText:
                            L10n.format("ui.common.seconds_two_decimals", settings.lyricsFocusCascadeDuration)
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.snap_threshold"),
                        value: $settings.lyricsFocusSnapThreshold,
                        range: AppSettings.lyricsFocusSnapThresholdRange,
                        step: 0.001,
                        valueText:
                            L10n.format("ui.common.milliseconds", Int((settings.lyricsFocusSnapThreshold * 1_000).rounded()))
                    )
                } header: {
                    Text("ui.settings.lyrics.animation.section.movement")
                } footer: {
                    Text("ui.settings.lyrics.animation.movement.footer")
                }

                Section {
                    Toggle(
                        "ui.settings.lyrics.animation.enable_movement_bounce",
                        isOn:
                            $settings
                                .lyricsFocusCascadeBounceEnabled
                    )

                    if settings.lyricsFocusCascadeBounceEnabled {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.animation.maximum_bounce"),
                            value: $settings.lyricsFocusCascadeBounce,
                            range:
                                AppSettings
                                    .lyricsFocusCascadeBounceRange,
                            step: 0.01,
                            valueText:
                                L10n.percent(settings.lyricsFocusCascadeBounce)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.animation.bounce_gradient"),
                            value:
                                $settings
                                    .lyricsFocusCascadeBounceGradient,
                            range:
                                AppSettings
                                    .lyricsFocusCascadeBounceGradientRange,
                            step: 0.01,
                            valueText:
                                L10n.percent(settings.lyricsFocusCascadeBounceGradient)
                        )
                    }

                    Toggle(
                        "ui.settings.lyrics.animation.enable_scale_bounce",
                        isOn:
                            $settings
                                .lyricsFocusScaleBounceEnabled
                    )

                    if settings.lyricsFocusScaleBounceEnabled {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.animation.scale_bounce_duration"),
                            value:
                                $settings
                                    .lyricsFocusScaleBounceDuration,
                            range:
                                AppSettings
                                    .lyricsFocusScaleBounceDurationRange,
                            step: 0.01,
                            valueText:
                                L10n.format("ui.common.seconds_two_decimals", settings.lyricsFocusScaleBounceDuration)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.animation.scale_bounce_elasticity"),
                            value: $settings.lyricsFocusScaleBounce,
                            range:
                                AppSettings
                                    .lyricsFocusScaleBounceRange,
                            step: 0.01,
                            valueText:
                                L10n.percent(settings.lyricsFocusScaleBounce)
                        )
                    }

                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.animation.focus_color_lead"),
                        value: $settings.lyricsFocusColorLeadTime,
                        range:
                            AppSettings
                                .lyricsFocusColorLeadTimeRange,
                        step: 0.005,
                        valueText:
                            L10n.format("ui.common.milliseconds", Int((settings.lyricsFocusColorLeadTime * 1_000).rounded()))
                    )
                } header: {
                    Text("ui.settings.lyrics.animation.section.bounce_focus")
                } footer: {
                    Text("ui.settings.lyrics.animation.bounce_focus.footer")
                }
            } else if settings.lyricsStyle == .appleMusic {
                Section {
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.animation.forward_line_delay"),
                        value: L10n.format("ui.common.milliseconds", 50)
                    )
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.animation.reverse_line_delay"),
                        value: L10n.format("ui.common.milliseconds", 25)
                    )
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.animation.line_change_spring"),
                        value: "1 / 100 / 18"
                    )
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.animation.precise_word_line"),
                        value: L10n.string("ui.settings.lyrics.animation.dynamic_line_interval")
                    )
                } header: {
                    Text("ui.settings.lyrics.animation.section.apple_music_parameters")
                } footer: {
                    Text("ui.settings.lyrics.animation.apple_music.footer")
                }
            }
        }
        .navigationTitle("ui.settings.lyrics.animation.title")
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
