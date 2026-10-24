import SwiftUI

struct TextPVSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var preferences = settings.textPV

        Form {
            Section {
                Picker("ui.settings.text_pv.style", selection: $preferences.style) {
                    ForEach(TextPVStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("ui.settings.text_pv.template.section")
            } footer: {
                Text(preferences.style.description)
            }

            Section {
                valueSlider(
                    title: L10n.string("ui.settings.text_pv.intensity"),
                    value: $preferences.motionIntensity,
                    range: TextPVPreferences.motionIntensityRange
                )

                valueSlider(
                    title: L10n.string("ui.settings.text_pv.speed"),
                    value: $preferences.animationSpeed,
                    range: TextPVPreferences.animationSpeedRange
                )
            } header: {
                Text("ui.settings.text_pv.playback.section")
            } footer: {
                Text("ui.settings.text_pv.playback.footer")
            }

            Section {
                Button("ui.settings.text_pv.reset", role: .destructive) {
                    showsResetConfirmation = true
                }
            }
        }
        .navigationTitle("ui.settings.lyrics.style.text_pv")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("ui.settings.text_pv.reset.confirmation", isPresented: $showsResetConfirmation) {
            Button("ui.settings.reset.action", role: .destructive) {
                settings.textPV.reset()
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        let valueText = L10n.percent(value.wrappedValue)

        return VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: 0.1)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}
