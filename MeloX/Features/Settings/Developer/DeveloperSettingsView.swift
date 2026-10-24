import SwiftUI

struct DeveloperSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "ui.settings.developer.beatnet_panel",
                    isOn: $settings.beatNetDebugEnabled
                )

                LabeledContent(
                    L10n.string("ui.settings.developer.entry"),
                    value: L10n.string("ui.settings.developer.entry.value")
                )
            } header: {
                Text("ui.settings.developer.debug.section")
            } footer: {
                Text(
                    "ui.settings.developer.debug.footer"
                )
            }
        }
        .navigationTitle("ui.settings.catalog.developer.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
