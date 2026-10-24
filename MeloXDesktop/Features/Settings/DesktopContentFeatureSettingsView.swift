import SwiftUI

struct DesktopContentFeatureSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        Form {
            Section("ui.settings.content_features.section") {
                ForEach(ContentFeature.allCases) { feature in
                    Toggle(isOn: binding(for: feature)) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feature.title)
                                Text(feature.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: feature.systemImage)
                        }
                    }
                }
            }

            Section {
                Text("ui.settings.content_features.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.columns)
        .padding()
    }

    private func binding(
        for feature: ContentFeature
    ) -> Binding<Bool> {
        Binding(
            get: { model.settings.isContentFeatureEnabled(feature) },
            set: { isEnabled in
                model.settings.setContentFeature(
                    feature,
                    isEnabled: isEnabled
                )
                model.ensureSelectedSectionIsEnabled()
                guard isEnabled else { return }
                Task { await reload(feature) }
            }
        )
    }

    private func reload(_ feature: ContentFeature) async {
        switch feature {
        case .podcasts:
            async let homeLoad: Void = model.home.load(force: true)
            async let libraryLoad: Void = model.library.refresh(force: true)
            _ = await (homeLoad, libraryLoad)
        case .cloudMusic:
            await model.cloud.refresh(force: true)
        case .listeningHistory:
            await model.library.refresh(force: true)
        case .downloads:
            break
        }
    }
}
