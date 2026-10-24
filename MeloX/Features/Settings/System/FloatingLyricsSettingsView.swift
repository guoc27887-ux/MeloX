import SwiftUI

struct FloatingLyricsSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(FloatingLyricsController.self) private var floatingLyrics

    var body: some View {
        @Bindable var preferences = settings.floatingLyrics

        Form {
            Section {
                LabeledContent(
                    L10n.string("ui.settings.floating_lyrics.pip"),
                    value: floatingLyrics.isSupported
                        ? L10n.string("ui.common.supported")
                        : L10n.string("ui.common.unsupported")
                )

                Toggle(
                    "ui.settings.floating_lyrics.show_translation",
                    isOn: $preferences.showsTranslation
                )
                Toggle(
                    "ui.settings.floating_lyrics.show_next",
                    isOn: $preferences.showsNextLine
                )

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(
                        L10n.string("ui.settings.floating_lyrics.text_size"),
                        value: L10n.percent(preferences.fontScale)
                    )
                    Slider(
                        value: $preferences.fontScale,
                        in: FloatingLyricsPreferences.fontScaleRange,
                        step: 0.05
                    )
                    .accessibilityLabel("ui.settings.floating_lyrics.text_size.accessibility")
                }
            } header: {
                Text("ui.common.display")
            } footer: {
                Text("ui.settings.floating_lyrics.display.footer")
            }

            Section {
                Label(
                    "ui.settings.floating_lyrics.usage.description",
                    systemImage: "pip"
                )
            } header: {
                Text("ui.settings.floating_lyrics.usage.section")
            }
        }
        .navigationTitle("ui.settings.catalog.floating.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
