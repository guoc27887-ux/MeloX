import SwiftUI

struct LyricsAppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        @Bindable var appleMusicLyrics = settings.appleMusicLyrics
        @Bindable var interlude = settings.lyricsInterlude

        Form {
            Section {
                Picker("ui.settings.lyrics.appearance.style", selection: $settings.lyricsStyle) {
                    ForEach(LyricsStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }

                if settings.lyricsStyle == .textPV {
                    NavigationLink {
                        TextPVSettingsView()
                    } label: {
                        LabeledContent(
                            L10n.string("ui.settings.text_pv.title"),
                            value: settings.textPV.style.title
                        )
                    }
                }

                if settings.lyricsStyle == .appleMusic {
                    Picker(
                        "ui.settings.lyrics.appearance.motion_preset",
                        selection: $appleMusicLyrics.motionPreset
                    ) {
                        ForEach(AppleMusicLyricsMotionPreset.allCases) {
                            preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                }
            } header: {
                Text("ui.settings.lyrics.appearance.section.style")
            } footer: {
                Text(styleDescription)
            }

            Section {
                if appleMusicLyrics.usesAppleMusic26Motion,
                   settings.lyricsStyle == .appleMusic {
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.appearance.body_font_size"),
                        value: L10n.format("ui.common.points", 36)
                    )
                    LabeledContent(
                        L10n.string("ui.settings.lyrics.appearance.font_weight"),
                        value: L10n.string("ui.settings.font_weight.bold")
                    )
                } else {
                    valueSlider(
                        title: L10n.string("ui.settings.lyrics.appearance.font_size"),
                        value: $settings.lyricsFontSize,
                        range: 20...36,
                        step: 1,
                        valueText: L10n.format("ui.common.points", Int(settings.lyricsFontSize))
                    )

                    Picker(
                        "ui.settings.lyrics.appearance.font_weight",
                        selection: $settings.lyricsFontWeight
                    ) {
                        ForEach(LyricsFontWeight.allCases) { weight in
                            Text(weight.title).tag(weight)
                        }
                    }
                }
            } header: {
                Text("ui.settings.lyrics.appearance.section.typography")
            } footer: {
                Text(typographyDescription)
            }

            if settings.lyricsStyle == .appleMusic {
                Section {
                    Picker(
                        "ui.settings.lyrics.appearance.intro_interlude",
                        selection: $interlude.mode
                    ) {
                        ForEach(
                            LyricsInterludePresentationMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if interlude.mode == .automatic {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.minimum_lrc_gap"),
                            value:
                                $interlude
                                    .minimumInferredGapDuration,
                            range:
                                LyricsInterludePreferences
                                    .inferredGapDurationRange,
                            step: 0.5,
                            valueText:
                                L10n.format("ui.common.seconds_decimal", interlude.minimumInferredGapDuration)
                        )
                    }

                    if appleMusicLyrics.motionPreset == .custom {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.current_line_scale"),
                            value: $settings.lyricsCurrentLineScale,
                            range: AppSettings.lyricsCurrentLineScaleRange,
                            step: 0.01,
                            valueText:
                                L10n.percent(settings.lyricsCurrentLineScale)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.line_spacing"),
                            value: $settings.lyricsLineSpacing,
                            range: 12...36,
                            step: 1,
                            valueText:
                                Int(settings.lyricsLineSpacing).formatted(
                                    .number.locale(L10n.locale)
                                )
                        )
                    } else {
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.unfocused_scale"), value: "98%")
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.line_spacing"), value: L10n.format("ui.common.points", 25))
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.paragraph_spacing"), value: L10n.format("ui.common.points", 39))
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.first_line_position"), value: L10n.format("ui.common.points", 60))
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.focus_vertical_position"), value: L10n.format("ui.common.from_top_percent", 12))
                    }

                    if appleMusicLyrics.motionPreset == .custom {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.focus_vertical_position"),
                            value: $settings.lyricsFocusPosition,
                            range: AppSettings.lyricsFocusPositionRange,
                            step: 0.01,
                            valueText:
                                L10n.format("ui.common.from_top_percent", Int(settings.lyricsFocusPosition * 100))
                        )
                    }
                } header: {
                    Text("ui.settings.lyrics.appearance.section.apple_music_layout")
                } footer: {
                    Text(interludeDescription)
                }

                Section {
                    if appleMusicLyrics.motionPreset == .custom {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.base_blur"),
                            value: $settings.lyricsBlurIntensity,
                            range: 0...2,
                            step: 0.1,
                            valueText:
                                settings.lyricsBlurIntensity.formatted(
                                    .number.precision(
                                        .fractionLength(1)
                                    )
                                    .locale(L10n.locale)
                                )
                        )
                    } else {
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.unfocused_blur"), value: L10n.format("ui.common.points", 3))
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.maximum_blur"), value: L10n.format("ui.common.points", 4))
                    }

                    Toggle(
                        appleMusicLyrics.usesAppleMusic26Motion
                            ? L10n.string("ui.settings.lyrics.appearance.clear_blur_browsing")
                            : L10n.string("ui.settings.lyrics.appearance.uniform_dimming_browsing"),
                        isOn:
                            $settings
                                .lyricsUsesUniformDimmingWhileBrowsing
                    )

                    if appleMusicLyrics.motionPreset == .custom {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.distance_blur_scale"),
                            value: $settings.lyricsDistanceBlurScale,
                            range: AppSettings.lyricsDistanceBlurScaleRange,
                            step: 0.05,
                            valueText:
                                L10n.percent(settings.lyricsDistanceBlurScale)
                        )

                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.hidden_ui_blur_scale"),
                            value:
                                $settings
                                    .lyricsHiddenInterfaceBlurScale,
                            range: AppSettings.lyricsDistanceBlurScaleRange,
                            step: 0.05,
                            valueText:
                                L10n.percent(settings.lyricsHiddenInterfaceBlurScale)
                        )
                    }

                    if appleMusicLyrics.motionPreset == .custom {
                        valueSlider(
                            title: L10n.string("ui.settings.lyrics.appearance.unfocused_dimming"),
                            value: $settings.lyricsDimAmount,
                            range: 0...1,
                            step: 0.1,
                            valueText:
                                L10n.percent(settings.lyricsDimAmount)
                        )
                    } else {
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.unfocused_text"), value: "17.5%")
                        LabeledContent(L10n.string("ui.settings.lyrics.appearance.upcoming_text"), value: "35%")
                    }
                } header: {
                    Text("ui.settings.lyrics.appearance.section.apple_music_focus")
                } footer: {
                    Text("ui.settings.lyrics.appearance.focus.footer")
                }
            }
        }
        .navigationTitle("ui.settings.lyrics.appearance.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var styleDescription: String {
        guard settings.lyricsStyle == .appleMusic else {
            return settings.lyricsStyle.description
        }
        return settings.lyricsStyle.description
            + "\n"
            + settings.appleMusicLyrics.motionPreset.description
    }

    private var typographyDescription: String {
        if settings.lyricsStyle == .appleMusic,
           settings.appleMusicLyrics.usesAppleMusic26Motion {
            return L10n.string("ui.settings.lyrics.appearance.typography.footer.fixed")
        }
        return L10n.string("ui.settings.lyrics.appearance.typography.footer")
    }

    private var interludeDescription: String {
        L10n.format(
            "ui.settings.lyrics.appearance.interlude.footer",
            settings.lyricsInterlude.mode.description
        )
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
