import SwiftUI

struct ReleaseNotesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    let releaseNotes: AppReleaseNotes?
    let currentVersion: String

    @State private var showsResetConfirmation = false
    @State private var isResettingSettings = false
    @State private var hasResetPlayerSettings = false

    init(
        releaseNotes: AppReleaseNotes?,
        currentVersion: String = Bundle.main.appReleaseVersion
    ) {
        self.releaseNotes = releaseNotes
        self.currentVersion = currentVersion
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("MeloX \(displayVersion)")
                        .font(.title2.bold())

                    Text("ui.release_notes.current_version")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                if !visibleEntries.isEmpty {
                    ForEach(visibleEntries.indices, id: \.self) { index in
                        Text(visibleEntries[index])
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ContentUnavailableView(
                        "ui.release_notes.empty.title",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(emptyStateDescription)
                    )
                }
            } header: {
                Text("ui.release_notes.section.changes")
            } footer: {
                if let previousVersion = releaseNotes?.displayPreviousVersion {
                    Text(L10n.format("ui.release_notes.version_range", previousVersion, displayVersion))
                }
            }

            Section {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    HStack {
                        Label(
                            hasResetPlayerSettings
                                ? L10n.string("ui.release_notes.reset.completed")
                                : L10n.string("ui.release_notes.reset.action"),
                            systemImage: hasResetPlayerSettings
                                ? "checkmark.circle"
                                : "arrow.counterclockwise"
                        )

                        Spacer()

                        if isResettingSettings {
                            ProgressView()
                        }
                    }
                }
                .disabled(
                    isResettingSettings || hasResetPlayerSettings
                )
                .confirmationDialog(
                    "ui.release_notes.reset.confirmation",
                    isPresented: $showsResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("ui.release_notes.reset.confirm", role: .destructive) {
                        resetPlayerSettings()
                    }
                    Button("ui.common.cancel", role: .cancel) {}
                } message: {
                    Text("ui.release_notes.reset.confirmation_message")
                }
            } header: {
                Text("ui.release_notes.section.tuning")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "ui.release_notes.reset.warning",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)

                    Text(
                        resetScopeDescription
                    )
                }
            }
        }
        .navigationTitle("ui.release_notes.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayVersion: String {
        releaseNotes?.displayVersion
            ?? AppVersion.displayName(for: currentVersion)
    }

    private var visibleEntries: [String] {
        let entries = releaseNotes?.entries ?? []
        guard !AppFeatureAvailability.downloads else { return entries }
        let downloadTerms = L10n.values("ui.release_notes.download_terms")
            .flatMap { $0.split(separator: "|").map(String.init) }
        return entries.filter { entry in
            !downloadTerms.contains { entry.localizedCaseInsensitiveContains($0) }
        }
    }

    private var resetScopeDescription: String {
        if AppFeatureAvailability.downloads {
            return L10n.string("ui.release_notes.reset.scope.downloads")
        }
        return L10n.string("ui.release_notes.reset.scope")
    }

    private var emptyStateDescription: String {
        if releaseNotes == nil {
            return L10n.string("ui.release_notes.empty.invalid_build")
        }
        return L10n.string("ui.release_notes.empty.no_public_changes")
    }

    private func resetPlayerSettings() {
        guard !isResettingSettings else { return }
        isResettingSettings = true

        Task { @MainActor in
            await PlayerSettingsResetter.reset(
                settings: settings,
                player: player
            )
            isResettingSettings = false
            hasResetPlayerSettings = true
        }
    }
}
