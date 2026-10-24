import SwiftUI

struct DesktopLyricsContentSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    private var usesWordByWordPresentation: Bool {
        model.settings.lyricsWordByWord
            || model.settings.lyricsPseudoWordByWord
    }

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section("ui.settings.lyrics.content.section.translation_pronunciation") {
                    Toggle(
                        "ui.settings.lyrics.content.show_romanization",
                        isOn: $settings.lyricsRomanizationEnabled
                    )
                    if settings.lyricsRomanizationEnabled {
                        Picker(
                            "ui.settings.lyrics.content.romanization_display_range",
                            selection:
                                $settings.lyricsRomanizationDisplayMode
                        ) {
                            ForEach(
                                LyricsTranslationDisplayMode.allCases
                            ) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.romanization_size")
                            Slider(
                                value:
                                    $settings.lyricsRomanizationFontScale,
                                in: 0.5...0.8,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsRomanizationFontScale)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.romanization_brightness")
                            Slider(
                                value: $settings.lyricsRomanizationOpacity,
                                in: 0.4...0.9,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsRomanizationOpacity)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }

                    Toggle(
                        "ui.settings.lyrics.content.show_translation",
                        isOn: $settings.lyricsTranslationEnabled
                    )
                    if settings.lyricsTranslationEnabled {
                        Picker(
                            "ui.settings.lyrics.content.translation_display_range",
                            selection:
                                $settings.lyricsTranslationDisplayMode
                        ) {
                            ForEach(
                                LyricsTranslationDisplayMode.allCases
                            ) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.translation_size")
                            Slider(
                                value: $settings.lyricsTranslationFontScale,
                                in: 0.5...0.8,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsTranslationFontScale)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.translation_brightness")
                            Slider(
                                value: $settings.lyricsTranslationOpacity,
                                in: 0.4...0.9,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsTranslationOpacity)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }
                }

                Section("ui.settings.lyrics.content.section.source") {
                    Picker(
                        "ui.settings.lyrics.content.default_source",
                        selection: $settings.lyricsSourcePreference
                    ) {
                        ForEach(LyricSourcePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    Toggle(
                        "ui.settings.lyrics.content.amll_source",
                        isOn: $settings.lyricsAMLLSourceEnabled
                    )
                    Toggle(
                        "ui.settings.lyrics.content.qq_source",
                        isOn: $settings.lyricsQQMusicSourceEnabled
                    )
                    Text("ui.settings.lyrics.content.source.footer")
                        .foregroundStyle(.secondary)
                }

                Section("ui.settings.lyrics.content.section.performer_layout") {
                    Toggle(
                        "ui.settings.lyrics.content.duet_layout",
                        isOn: $settings.lyricsDuetLayoutEnabled
                    )
                    Text("ui.settings.lyrics.content.duet_layout.footer")
                        .foregroundStyle(.secondary)
                }

                Section("ui.settings.lyrics.content.section.word_by_word") {
                    Toggle(
                        "ui.settings.lyrics.content.official_word_by_word",
                        isOn: $settings.lyricsWordByWord
                    )
                    Toggle(
                        "ui.settings.lyrics.content.pseudo_word_by_word",
                        isOn: $settings.lyricsPseudoWordByWord
                    )
                }

                if usesWordByWordPresentation {
                    Section("ui.settings.lyrics.content.section.highlight") {
                        Picker(
                            "ui.settings.lyrics.content.lift_mode",
                            selection: $settings.lyricsLiftMode
                        ) {
                            ForEach(LyricsLiftMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("ui.settings.lyrics.content.highlight_gradient_width")
                            Slider(
                                value:
                                    $settings.lyricsHighlightGradientWidth,
                                in:
                                    AppSettings
                                        .lyricsHighlightGradientWidthRange,
                                step: 0.1
                            )
                            Text(
                                settings.lyricsHighlightGradientWidth
                                    .formatted(
                                        .number.precision(
                                            .fractionLength(1)
                                        )
                                        .locale(L10n.locale)
                                    )
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.gradient_reduction")
                            Slider(
                                value:
                                    $settings
                                        .lyricsHighlightGradientReduction,
                                in:
                                    AppSettings
                                        .lyricsHighlightGradientReductionRange,
                                step: 0.05
                            )
                            Text(
                                L10n.percent(settings.lyricsHighlightGradientReduction)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }

                    Section("ui.settings.lyrics.content.section.long_tone_glow") {
                        Picker(
                            "ui.settings.lyrics.content.long_tone_detection",
                            selection:
                                $settings.lyricsLongSyllableDetectionMode
                        ) {
                            ForEach(
                                LyricsLongSyllableDetectionMode.allCases
                            ) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("ui.settings.lyrics.content.long_tone_threshold")
                            Slider(
                                value:
                                    $settings
                                        .lyricsLongSyllableDurationThreshold,
                                in:
                                    AppSettings
                                        .lyricsLongSyllableDurationThresholdRange,
                                step: 0.05
                            )
                            Text(
                                L10n.format(
                                    "ui.common.seconds_two_decimals",
                                    settings.lyricsLongSyllableDurationThreshold
                                )
                            )
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                        }

                        HStack {
                            Text("ui.settings.lyrics.content.long_tone_expansion")
                            Slider(
                                value:
                                    $settings.lyricsLongToneExpansionAmount,
                                in:
                                    AppSettings
                                        .lyricsLongToneExpansionAmountRange,
                                step: 0.01
                            )
                            Text(
                                L10n.percent(settings.lyricsLongToneExpansionAmount)
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        Toggle(
                            "ui.settings.lyrics.content.glow_effect",
                            isOn: $settings.lyricsGlowEnabled
                        )
                        if settings.lyricsGlowEnabled {
                            Toggle(
                                "ui.settings.lyrics.content.glow_long_tones_only",
                                isOn:
                                    $settings.lyricsGlowLongSyllablesOnly
                            )
                            HStack {
                                Text("ui.settings.lyrics.content.glow_intensity")
                                Slider(
                                    value: $settings.lyricsGlowIntensity,
                                    in:
                                        AppSettings
                                            .lyricsGlowIntensityRange,
                                    step: 0.1
                                )
                                Text(
                                    settings.lyricsGlowIntensity.formatted(
                                        .number.precision(
                                            .fractionLength(1)
                                        )
                                        .locale(L10n.locale)
                                    )
                                )
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                            }
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
