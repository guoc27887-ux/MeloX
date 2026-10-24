import SwiftUI

struct DesktopAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    @State private var isCheckingUpdate = false
    @State private var updateAlert: DesktopAboutUpdateAlert?

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 176, height: 176)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("MeloX")
                    .font(.system(size: 34, weight: .semibold))

                Text(versionDescription)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                Text("ui.desktop.about.developer")
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                Spacer(minLength: 20)

                Text(copyrightNotice)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 14)

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await checkForUpdates()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(
                                isCheckingUpdate
                                    ? L10n.string("ui.about.checking_updates")
                                    : L10n.string("ui.about.check_updates")
                            )
                        }
                    }
                    .disabled(isCheckingUpdate)

                    Button("ui.about.github") {
                        openURL(AppUpdateService.repositoryURL)
                    }

                    Button("ui.legal.projects_licenses.title") {
                        openWindow(id: "licenses")
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 52)
        .padding(.horizontal, 40)
        .padding(.bottom, 28)
        .frame(width: 600, height: 320)
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

    private var versionDescription: String {
        L10n.format(
            "ui.desktop.about.version_build",
            Bundle.main.appReleaseVersion,
            Bundle.main.appBuildNumber
        )
    }

    private var copyrightNotice: String {
        let year = Calendar.current.component(.year, from: .now)
        return L10n.format("ui.desktop.about.copyright", year)
    }

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer {
            isCheckingUpdate = false
        }

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: Bundle.main.appReleaseVersion
            )

            if result.hasUpdate {
                updateAlert = DesktopAboutUpdateAlert(
                    title: L10n.string("ui.about.update_available.title"),
                    message: L10n.format(
                        "ui.desktop.about.update_available.message",
                        result.currentVersion,
                        result.latestVersion
                    ),
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = DesktopAboutUpdateAlert(
                    title: L10n.string("ui.about.up_to_date.title"),
                    message: L10n.format("ui.about.up_to_date.message", result.currentVersion),
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = DesktopAboutUpdateAlert(
                title: L10n.string("ui.about.update_check_failed.title"),
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }
}

private struct DesktopAboutUpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let releaseURL: URL?
}
