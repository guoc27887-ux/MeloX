import SwiftUI

struct DesktopLyricsAppearanceSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var appleMusicLyrics = model.settings.appleMusicLyrics

        ScrollView {
            Form {
                Section("ui.settings.lyrics.appearance.section.typography") {
                    LabeledContent("ui.settings.lyrics.appearance.style", value: LyricsStyle.appleMusic.title)

                    Picker(
                        "ui.settings.lyrics.appearance.motion_preset",
                        selection: $appleMusicLyrics.motionPreset
                    ) {
                        ForEach(AppleMusicLyricsMotionPreset.allCases) {
                            preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    if appleMusicLyrics.usesAppleMusic26Motion {
                        LabeledContent(
                            "ui.settings.lyrics.appearance.body_font_size",
                            value: L10n.string("ui.desktop.lyrics.fixed.responsive_font_sizes")
                        )
                        LabeledContent(
                            "ui.settings.lyrics.appearance.font_weight",
                            value: L10n.string("ui.settings.font_weight.bold")
                        )
                    } else {
                        HStack {
                            Text("ui.settings.lyrics.appearance.font_size")
                            Slider(
                                value: $settings.lyricsFontSize,
                                in: AppSettings.desktopLyricsFontSizeRange,
                                step: 1
                            )
                            Text(L10n.format("ui.common.points", Int(settings.lyricsFontSize.rounded())))
                                .monospacedDigit()
                                .frame(width: 62, alignment: .trailing)
                        }

                        Picker(
                            "ui.settings.lyrics.appearance.font_weight",
                            selection: $settings.lyricsFontWeight
                        ) {
                            ForEach(LyricsFontWeight.allCases) { weight in
                                Text(weight.title).tag(weight)
                            }
                        }
                    }

                    Text(appleMusicLyrics.motionPreset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("ui.settings.lyrics.appearance.section.apple_music_layout") {
                    Toggle(
                        "ui.settings.lyrics.appearance.intro_interlude",
                        isOn: $settings.lyricsInterludeCountdownEnabled
                    )

                    if appleMusicLyrics.usesAppleMusic26Motion {
                        LabeledContent("ui.settings.lyrics.appearance.unfocused_scale", value: "98%")
                        LabeledContent("ui.settings.lyrics.appearance.line_spacing", value: L10n.format("ui.common.points", 25))
                        LabeledContent("ui.desktop.lyrics.fixed.line_wrap_addition", value: L10n.format("ui.common.points", 0))
                        LabeledContent("ui.settings.lyrics.appearance.paragraph_spacing", value: L10n.format("ui.common.points", 39))
                        LabeledContent("ui.settings.lyrics.appearance.first_line_position", value: L10n.format("ui.common.points", 60))
                        LabeledContent(
                            "ui.desktop.lyrics.fixed.focus_rule",
                            value: L10n.string("ui.desktop.lyrics.fixed.align_artwork_center")
                        )
                        LabeledContent("ui.desktop.lyrics.fixed.top_safe_offset", value: L10n.format("ui.common.points", 22))
                        LabeledContent("ui.desktop.lyrics.fixed.top_gradient_end", value: "8%")
                        LabeledContent(
                            "ui.desktop.lyrics.fixed.rhythm_indicator",
                            value: L10n.string("ui.desktop.lyrics.fixed.rhythm_indicator_value")
                        )
                        LabeledContent("ui.desktop.lyrics.fixed.duet_width", value: "85%")
                        LabeledContent("ui.desktop.lyrics.fixed.background_vocal_spacing", value: L10n.format("ui.common.points", 15))
                    } else {
                        HStack {
                            Text("ui.settings.lyrics.appearance.current_line_scale")
                            Slider(
                                value: $settings.lyricsCurrentLineScale,
                                in: AppSettings.lyricsCurrentLineScaleRange,
                                step: 0.01
                            )
                            Text(
                                L10n.percent(settings.lyricsCurrentLineScale)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.appearance.line_spacing")
                            Slider(
                                value: $settings.lyricsLineSpacing,
                                in: AppSettings.desktopLyricsLineSpacingRange,
                                step: 1
                            )
                            Text(
                                Int(settings.lyricsLineSpacing.rounded()).formatted(
                                    .number.locale(L10n.locale)
                                )
                            )
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.appearance.focus_vertical_position")
                            Slider(
                                value: $settings.lyricsFocusPosition,
                                in: AppSettings.lyricsFocusPositionRange,
                                step: 0.01
                            )
                            Text(
                                L10n.percent(settings.lyricsFocusPosition)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }
                }

                Section("ui.settings.lyrics.appearance.section.apple_music_focus") {
                    if appleMusicLyrics.usesAppleMusic26Motion {
                        LabeledContent("ui.settings.lyrics.appearance.unfocused_blur", value: L10n.format("ui.common.points", 3))
                        LabeledContent("ui.settings.lyrics.appearance.maximum_blur", value: L10n.format("ui.common.points", 4))
                        LabeledContent("ui.settings.lyrics.appearance.unfocused_text", value: "17.5%")
                        LabeledContent("ui.settings.lyrics.appearance.upcoming_text", value: "35%")
                    } else {
                        HStack {
                            Text("ui.settings.lyrics.appearance.base_blur")
                            Slider(
                                value: $settings.lyricsBlurIntensity,
                                in: AppSettings.lyricsBlurIntensityRange,
                                step: 0.1
                            )
                            Text(
                                settings.lyricsBlurIntensity.formatted(
                                    .number
                                        .precision(.fractionLength(1))
                                        .locale(L10n.locale)
                                )
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.appearance.distance_blur_scale")
                            Slider(
                                value: $settings.lyricsDistanceBlurScale,
                                in: AppSettings.lyricsDistanceBlurScaleRange,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsDistanceBlurScale)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.appearance.unfocused_dimming")
                            Slider(
                                value: $settings.lyricsDimAmount,
                                in: 0...1,
                                step: 0.1
                            )
                            Text(
                                L10n.percent(settings.lyricsDimAmount)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
    }
}
