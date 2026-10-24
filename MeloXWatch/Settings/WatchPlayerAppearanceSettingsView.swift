import SwiftUI

struct WatchPlayerAppearanceSettingsView: View {
    @AppStorage(WatchPreferenceKey.shrinksPausedArtwork)
    private var shrinksPausedArtwork = false
    @AppStorage(WatchPreferenceKey.showsArtist)
    private var showsArtist = true
    @AppStorage(WatchPreferenceKey.playerBackgroundBlur)
    private var backgroundBlur = 18.0
    @AppStorage(WatchPreferenceKey.playerBackgroundDim)
    private var backgroundDim = 0.62
    @AppStorage(WatchPreferenceKey.playerBackgroundSaturation)
    private var backgroundSaturation = 1.15

    var body: some View {
        Form {
            Section("ui.watch.appearance.blurred_background") {
                LabeledContent(
                    "ui.watch.appearance.blur_radius",
                    value: backgroundBlur.formatted(
                        .number.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $backgroundBlur, in: 8...32)
                    .accessibilityLabel("ui.watch.appearance.blur_radius_accessibility")

                LabeledContent(
                    "ui.watch.appearance.dim_amount",
                    value: backgroundDim.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $backgroundDim, in: 0.35...0.85)
                    .accessibilityLabel("ui.watch.appearance.dim_accessibility")

                LabeledContent(
                    "ui.watch.appearance.saturation",
                    value: backgroundSaturation.formatted(
                        .percent.precision(.fractionLength(0)).locale(L10n.locale)
                    )
                )
                Slider(value: $backgroundSaturation, in: 0.5...1.5)
                    .accessibilityLabel("ui.watch.appearance.saturation_accessibility")
            }

            Section("ui.watch.appearance.artwork") {
                Toggle("ui.settings.player_appearance.shrink_paused_artwork", isOn: $shrinksPausedArtwork)
            }

            Section("ui.watch.appearance.information") {
                Toggle("ui.watch.appearance.show_artist", isOn: $showsArtist)
            }

            Section {
                Text("ui.watch.appearance.footer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ui.watch.settings.player_appearance")
    }
}
