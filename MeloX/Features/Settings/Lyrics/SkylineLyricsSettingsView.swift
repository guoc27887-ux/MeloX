import SwiftUI

struct SkylineLyricsSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var preferences = settings.skylineLyrics

        Form {
            Section {
                Toggle("ui.settings.skyline.keep_screen_awake", isOn: $preferences.keepsScreenAwake)
            } footer: {
                Text("ui.settings.skyline.keep_screen_awake.footer")
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.skyline.current_font_size"),
                    value: $preferences.currentLyricFontSize,
                    range: 36...84,
                    step: 1,
                    valueText: pointValue(preferences.currentLyricFontSize)
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.maximum_word_scale"),
                    value: $preferences.currentLyricMaximumScale,
                    range: 1...1.2,
                    step: 0.01,
                    valueText: scaleValue(preferences.currentLyricMaximumScale)
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.center_width"),
                    value: $preferences.currentLyricsWidth,
                    range: 0.4...0.82,
                    step: 0.02,
                    valueText: percentValue(preferences.currentLyricsWidth)
                )
            } header: {
                Text("ui.settings.skyline.section.current_lyric")
            } footer: {
                Text("ui.settings.skyline.current_lyric.footer")
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.skyline.next_font_size"),
                    value: $preferences.nextLyricFontSize,
                    range: 14...44,
                    step: 1,
                    valueText: pointValue(preferences.nextLyricFontSize)
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.next_brightness"),
                    value: $preferences.nextLyricOpacity,
                    range: 0.2...0.8,
                    step: 0.05,
                    valueText: percentValue(preferences.nextLyricOpacity)
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.center_spacing"),
                    value: $preferences.currentLyricsSpacing,
                    range: 4...36,
                    step: 1,
                    valueText: pointValue(preferences.currentLyricsSpacing)
                )
            } header: {
                Text("ui.settings.skyline.section.next_lyric")
            } footer: {
                Text("ui.settings.skyline.next_lyric.footer")
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.skyline.ambient_font_size"),
                    value: $preferences.ambientFontSize,
                    range: 24...72,
                    step: 1,
                    valueText: pointValue(preferences.ambientFontSize)
                )

                Picker(
                    "ui.settings.skyline.maximum_characters_per_group",
                    selection: $preferences.ambientMaximumCharacters
                ) {
                    Text(L10n.format("ui.common.characters", 1)).tag(1)
                    Text(L10n.format("ui.common.characters", 2)).tag(2)
                    Text(L10n.format("ui.common.characters", 3)).tag(3)
                    Text(L10n.format("ui.common.characters", 4)).tag(4)
                }

                Stepper(
                    value: $preferences.ambientMaximumVisibleTexts,
                    in: 4...24
                ) {
                    LabeledContent(
                        L10n.string("ui.settings.skyline.visible_text_limit"),
                        value: L10n.format("ui.common.groups", preferences.ambientMaximumVisibleTexts)
                    )
                }

                valueSlider(
                    title: L10n.string("ui.settings.skyline.ambient_brightness"),
                    value: $preferences.ambientOpacity,
                    range: 0.4...1.8,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientOpacity)
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.ambient_blur"),
                    value: $preferences.ambientBlur,
                    range: 0...2,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientBlur)
                )
            } header: {
                Text("ui.settings.skyline.section.ambient_lyrics")
            } footer: {
                Text("ui.settings.skyline.ambient_lyrics.footer")
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.skyline.maximum_tilt"),
                    value: $preferences.ambientMaximumTilt,
                    range: 0...20,
                    step: 1,
                    valueText:
                        Int(preferences.ambientMaximumTilt).formatted(
                            .number.locale(L10n.locale)
                        ) + "°"
                )

                valueSlider(
                    title: L10n.string("ui.settings.skyline.drift_amount"),
                    value: $preferences.ambientDrift,
                    range: 0...2,
                    step: 0.1,
                    valueText: scaleValue(preferences.ambientDrift)
                )
            } header: {
                Text("ui.settings.skyline.section.ambient_motion")
            } footer: {
                Text("ui.settings.skyline.ambient_motion.footer")
            }

            Section {
                Button("ui.settings.skyline.reset", role: .destructive) {
                    showsResetConfirmation = true
                }
            }
        }
        .navigationTitle("ui.settings.skyline.title")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("ui.settings.skyline.reset.confirmation", isPresented: $showsResetConfirmation) {
            Button("ui.common.restore_defaults", role: .destructive) {
                preferences.reset()
            }
        }
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

    private func pointValue(_ value: Double) -> String {
        L10n.format("ui.common.points", Int(value))
    }

    private func percentValue(_ value: Double) -> String {
        value.formatted(
            .percent.precision(.fractionLength(0)).locale(L10n.locale)
        )
    }

    private func scaleValue(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(1)).locale(L10n.locale)
        ) + "×"
    }
}
