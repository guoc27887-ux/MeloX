import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings
    @Environment(AppReleaseNotesStore.self) private var releaseNotes

    @State private var isCheckingUpdate = false
    @State private var updateAlert: AppUpdateAlert?

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                VStack(spacing: 10) {
                    Image("MeloXLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    Text("MeloX")
                        .font(.title2.bold())

                    Text("ui.about.tagline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("ui.about.app_info.section") {
                LabeledContent("ui.about.version", value: releaseVersion)
                LabeledContent("ui.about.build", value: buildNumber)
            }

            Section {
                NavigationLink {
                    ReleaseNotesView(
                        releaseNotes: releaseNotes.currentReleaseNotes,
                        currentVersion: releaseNotes.currentVersion
                    )
                } label: {
                    HStack {
                        Label("ui.about.release_notes", systemImage: "doc.text")

                        Spacer()

                        Text("MeloX \(releaseVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("ui.about.check_updates_on_launch", isOn: $settings.checksUpdatesOnLaunch)

                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    HStack {
                        Label(
                            isCheckingUpdate
                                ? L10n.string("ui.about.checking_updates")
                                : L10n.string("ui.about.check_updates"),
                            systemImage: "arrow.triangle.2.circlepath"
                        )

                        Spacer()

                        if isCheckingUpdate {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCheckingUpdate)
            } header: {
                Text("ui.about.updates.section")
            } footer: {
                Text("ui.about.updates.footer")
            }

            Section("ui.about.melox.section") {
                Text("ui.about.description")
            }

            Section("ui.about.shareholders.section") {
                ForEach(shareholders, id: \.self) { shareholder in
                    ShareholderShowcaseView(name: shareholder)
                }
            }

            Section("ui.about.community.section") {
                Link(destination: officialWebsiteURL) {
                    HStack(spacing: 12) {
                        Label("ui.about.website", systemImage: "globe")

                        Spacer(minLength: 8)

                        Text("melox.luoxe.cn")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: AppUpdateService.repositoryURL) {
                    Label("ui.about.github", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: telegramURL) {
                    HStack(spacing: 12) {
                        Label("ui.about.telegram", systemImage: "paperplane")

                        Spacer(minLength: 8)

                        Text("@melox_official")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    ProjectLicensesView()
                } label: {
                    Label("ui.about.licenses", systemImage: "doc.text")
                }
            } header: {
                Text("ui.about.open_source.section")
            } footer: {
                Text("ui.about.open_source.footer")
            }

            Section("ui.about.disclaimer.section") {
                Text("ui.about.disclaimer")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ui.common.about")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $updateAlert) { alert in
            if let releaseURL = alert.releaseURL {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("ui.about.open_release_page")) {
                        openURL(releaseURL)
                    },
                    secondaryButton: .cancel(Text("ui.common.ok"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("ui.common.ok"))
                )
            }
        }
    }

    private var buildNumber: String {
        Bundle.main.appBuildNumber
    }

    private var releaseVersion: String {
        Bundle.main.appReleaseVersion
    }

    private let officialWebsiteURL = URL(string: "https://melox.luoxe.cn/")!
    private let telegramURL = URL(string: "https://t.me/melox_official")!

    // 股东致谢（不分先后或排名）：J1 Champ1on
    private let shareholders = ["J1 Champ1on"]

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer {
            isCheckingUpdate = false
        }

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: releaseVersion
            )

            if result.hasUpdate {
                updateAlert = AppUpdateAlert(
                    title: L10n.string("ui.about.update_available.title"),
                    message: L10n.format(
                        "ui.about.update_available.message",
                        result.currentVersion,
                        result.latestVersion
                    ),
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = AppUpdateAlert(
                    title: L10n.string("ui.about.up_to_date.title"),
                    message: L10n.format(
                        "ui.about.up_to_date.message",
                        result.currentVersion
                    ),
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = AppUpdateAlert(
                title: L10n.string("ui.about.update_check_failed.title"),
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }

}

private struct AppUpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let releaseURL: URL?
}
