import SwiftUI

struct WatchLyricsSettingsView: View {
    @AppStorage(WatchPreferenceKey.showsTranslation)
    private var showsTranslation = true
    @AppStorage(WatchPreferenceKey.showsRomanization)
    private var showsRomanization = false
    @AppStorage(WatchPreferenceKey.wordByWord)
    private var wordByWord = true
    @AppStorage(WatchPreferenceKey.lyricGlow)
    private var lyricGlow = true
    @AppStorage(WatchPreferenceKey.lyricGlowIntensity)
    private var glowIntensity = 1.0
    @AppStorage(WatchPreferenceKey.lyricAdvanceTime)
    private var advanceTime = 0.2
    @AppStorage(WatchPreferenceKey.lyricBlurIntensity)
    private var blurIntensity = 0.8
    @AppStorage(WatchPreferenceKey.lyricDistanceBlurScale)
    private var distanceBlurScale = 1.05
    @AppStorage(WatchPreferenceKey.lyricCurrentLineScale)
    private var currentLineScale = 1.02
    @AppStorage(WatchPreferenceKey.lyricHighRefreshRate)
    private var refreshRateRawValue = WatchLyricsRefreshRate.smooth.rawValue
    @AppStorage(WatchPreferenceKey.lyricDimAmount)
    private var dimAmount = 1.0
    @AppStorage(WatchPreferenceKey.lyricFocusPosition)
    private var focusPosition = 0.25
    @AppStorage(WatchPreferenceKey.lyricUniformBrowsingDimming)
    private var usesUniformBrowsingDimming = true
    @AppStorage(WatchPreferenceKey.lyricRomanizationFontScale)
    private var romanizationFontScale = 0.65
    @AppStorage(WatchPreferenceKey.lyricRomanizationOpacity)
    private var romanizationOpacity = 0.9
    @AppStorage(WatchPreferenceKey.lyricLiftMode)
    private var liftModeRawValue = WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDetectionMode)
    private var longToneDetectionModeRawValue =
        WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDurationThreshold)
    private var longToneDurationThreshold = 0.95
    @AppStorage(WatchPreferenceKey.lyricLongToneExpansionAmount)
    private var longToneExpansionAmount = 0.05

    var body: some View {
        Form {
            Section("ui.desktop.lyrics.page.content") {
                Toggle("ui.watch.lyrics.word_highlight", isOn: $wordByWord)
                Toggle("ui.settings.floating_lyrics.show_translation", isOn: $showsTranslation)
                Toggle("ui.settings.lyrics.content.show_romanization", isOn: $showsRomanization)

                LabeledContent(
                    "ui.settings.lyrics.content.romanization_size",
                    value: romanizationFontScale.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $romanizationFontScale, in: 0.45...0.85)
                    .disabled(!showsRomanization)
                    .accessibilityLabel("ui.settings.lyrics.content.romanization_size")

                LabeledContent(
                    "ui.settings.lyrics.content.romanization_brightness",
                    value: romanizationOpacity.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $romanizationOpacity, in: 0.4...1)
                    .disabled(!showsRomanization)
                    .accessibilityLabel("ui.settings.lyrics.content.romanization_brightness")
            }

            Section {
                Picker("ui.watch.lyrics.word_animation", selection: $refreshRateRawValue) {
                    ForEach(WatchLyricsRefreshRate.allCases) { rate in
                        Text(rate.title).tag(rate.rawValue)
                    }
                }
            } header: {
                Text("ui.settings.lyrics.animation.refresh_rate")
            } footer: {
                Text("ui.watch.lyrics.refresh.footer")
            }

            Section("ui.watch.lyrics.glow") {
                Toggle("ui.settings.lyrics.content.glow_effect", isOn: $lyricGlow)

                LabeledContent(
                    "ui.settings.lyrics.content.glow_intensity",
                    value: glowIntensity.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $glowIntensity, in: 0...1.5)
                    .disabled(!lyricGlow)
                    .accessibilityLabel("ui.settings.lyrics.content.glow_intensity")
            }

            Section("ui.watch.lyrics.progressive_blur") {
                LabeledContent(
                    "ui.settings.lyrics.appearance.base_blur",
                    value: blurIntensity.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $blurIntensity, in: 0...1.5)
                    .accessibilityLabel("ui.settings.lyrics.appearance.base_blur")

                LabeledContent(
                    "ui.settings.lyrics.appearance.distance_blur_scale",
                    value: distanceBlurScale.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $distanceBlurScale, in: 0...1.5)
                    .accessibilityLabel("ui.settings.lyrics.appearance.distance_blur_scale")

                LabeledContent(
                    "ui.settings.lyrics.appearance.unfocused_dimming",
                    value: dimAmount.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $dimAmount, in: 0...1)
                    .accessibilityLabel("ui.settings.lyrics.appearance.unfocused_dimming")

                Toggle(
                    "ui.settings.lyrics.appearance.uniform_dimming_browsing",
                    isOn: $usesUniformBrowsingDimming
                )
            }

            Section("ui.watch.lyrics.timing_focus") {
                LabeledContent(
                    "ui.settings.lyrics.interaction.advance_time",
                    value: L10n.format("ui.common.seconds_two_decimals", advanceTime)
                )
                Slider(value: $advanceTime, in: -0.5...0.8, step: 0.05)
                    .accessibilityLabel("ui.settings.lyrics.interaction.advance_time")

                LabeledContent(
                    "ui.settings.lyrics.appearance.current_line_scale",
                    value: currentLineScale.formatted(
                        .number.precision(.fractionLength(2)).locale(L10n.locale)
                    )
                )
                Slider(value: $currentLineScale, in: 1...1.15)
                    .accessibilityLabel("ui.settings.lyrics.appearance.current_line_scale")

                LabeledContent(
                    "ui.settings.lyrics.appearance.focus_vertical_position",
                    value: L10n.format(
                        "ui.watch.lyrics.focus_from_top",
                        focusPosition.formatted(
                            .percent.precision(.fractionLength(0)).locale(L10n.locale)
                        )
                    )
                )
                Slider(value: $focusPosition, in: 0.12...0.5)
                    .accessibilityLabel("ui.settings.lyrics.appearance.focus_vertical_position")
            }

            Section("ui.watch.lyrics.word_motion") {
                Picker("ui.settings.lyrics.content.lift_mode", selection: $liftModeRawValue) {
                    ForEach(WatchLyricTimingMode.allCases) { mode in
                        Text(mode.liftTitle).tag(mode.rawValue)
                    }
                }

                Picker(
                    "ui.settings.lyrics.content.long_tone_detection",
                    selection: $longToneDetectionModeRawValue
                ) {
                    ForEach(WatchLyricTimingMode.allCases) { mode in
                        Text(mode.detectionTitle).tag(mode.rawValue)
                    }
                }

                LabeledContent(
                    "ui.settings.lyrics.content.long_tone_threshold",
                    value: L10n.format(
                        "ui.common.seconds_two_decimals",
                        longToneDurationThreshold
                    )
                )
                Slider(
                    value: $longToneDurationThreshold,
                    in: 0.3...1.5,
                    step: 0.05
                )
                .accessibilityLabel("ui.settings.lyrics.content.long_tone_threshold")

                LabeledContent(
                    "ui.settings.lyrics.content.long_tone_expansion",
                    value: longToneExpansionAmount.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(
                    value: $longToneExpansionAmount,
                    in: 0...0.15,
                    step: 0.01
                )
                .accessibilityLabel("ui.settings.lyrics.content.long_tone_expansion")
            }
        }
        .navigationTitle("ui.watch.settings.lyrics")
    }
}
