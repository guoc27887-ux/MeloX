import SwiftUI

struct PlayerAppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker(
                    "ui.settings.player_appearance.background_style",
                    selection: $settings.playerBackgroundStyle
                ) {
                    ForEach(PlayerBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                valueSlider(
                    title: L10n.string("ui.settings.player_appearance.saturation"),
                    value: $settings.playerBackgroundSaturation,
                    range: 0.4...1.2,
                    step: 0.05,
                    valueText:
                        L10n.percent(settings.playerBackgroundSaturation)
                )

                if settings.playerBackgroundStyle != .blurredArtwork {
                    valueSlider(
                        title: L10n.string("ui.settings.player_appearance.motion_speed"),
                        value:
                            $settings
                                .playerBackgroundMotionIntensity,
                        range: 0.4...1.4,
                        step: 0.1,
                        valueText:
                            L10n.percent(settings.playerBackgroundMotionIntensity)
                    )

                    if settings.playerBackgroundStyle == .flowingLight {
                        Toggle(
                            "ui.settings.player_appearance.beat_vignette",
                            isOn:
                                $settings
                                    .playerBackgroundBeatEffectsEnabled
                        )
                    } else {
                        Toggle(
                            "ui.settings.player_appearance.audio_response",
                            isOn:
                                $settings
                                    .playerBackgroundAudioResponseEnabled
                        )
                    }
                } else {
                    valueSlider(
                        title: L10n.string("ui.settings.player_appearance.blur"),
                        value: $settings.playerBackgroundBlur,
                        range: 0...140,
                        step: 5,
                        valueText:
                            L10n.integer(Int(settings.playerBackgroundBlur))
                    )
                }

                Toggle(
                    "ui.settings.player_appearance.shrink_paused_artwork",
                    isOn: $settings.shrinksPausedArtwork
                )
            } header: {
                Text("ui.settings.player_appearance.background.section")
            } footer: {
                Text(backgroundFooter)
            }

            Section {
                Picker(
                    "ui.settings.player_appearance.screen_awake",
                    selection: $settings.playerScreenAwakeMode
                ) {
                    ForEach(PlayerScreenAwakeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("ui.settings.player_appearance.screen.section")
            } footer: {
                Text("ui.settings.player_appearance.screen.footer")
            }
        }
        .navigationTitle("ui.settings.catalog.player_appearance.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var backgroundFooter: String {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            L10n.string("ui.settings.player_appearance.background.apple_music.footer")
        case .flowingLight:
            L10n.string("ui.settings.player_appearance.background.flowing_light.footer")
        case .blurredArtwork:
            L10n.string("ui.settings.player_appearance.background.blurred_artwork.footer")
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
}
