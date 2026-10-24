import AppKit
import SwiftUI

extension View {
    func desktopLaunchExperience() -> some View {
        modifier(DesktopLaunchExperienceModifier())
    }
}

private struct DesktopLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DesktopAppModel.self) private var model

    @State private var hasInspectedClipboard = false
    @State private var hasCheckedForUpdates = false
    @State private var detectedLink: NeteaseMusicLink?
    @State private var updateAlert: DesktopAutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task {
                inspectClipboardIfNeeded()
                await checkForUpdatesIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                inspectClipboardIfNeeded()
            }
            .alert(
                detectedLink?.promptTitle ?? L10n.string("ui.clipboard.title"),
                isPresented: detectedLinkPresented
            ) {
                if let detectedLink {
                    Button(detectedLink.actionTitle) {
                        open(detectedLink)
                    }
                }
                Button("ui.common.ignore", role: .cancel) {}
            } message: {
                Text(
                    detectedLink?.promptMessage
                        ?? L10n.string("ui.clipboard.open_link_prompt")
                )
            }
            .alert(item: $updateAlert) { alert in
                Alert(
                    title: Text("ui.update.available.title"),
                    message: Text(alert.message),
                    primaryButton: .default(Text("ui.update.open_release_page")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("ui.common.later"))
                )
            }
    }

    private var detectedLinkPresented: Binding<Bool> {
        Binding(
            get: { detectedLink != nil },
            set: { isPresented in
                if !isPresented {
                    detectedLink = nil
                }
            }
        )
    }

    private func inspectClipboardIfNeeded() {
        guard !hasInspectedClipboard,
              scenePhase == .active else {
            return
        }
        hasInspectedClipboard = true

        guard model.settings.recognizesClipboardLinksOnLaunch,
              let text = NSPasteboard.general.string(forType: .string),
              let link = NeteaseMusicLinkParser.parse(text) else {
            return
        }
        detectedLink = link
    }

    private func open(_ link: NeteaseMusicLink) {
        switch link {
        case .song(let id):
            model.ui.isNowPlayingPresented = false
            model.ui.navigate(to: .song(id))
        case .listenTogether(let invitation):
            model.ui.sheet = .listenTogetherInvitation(invitation)
        }
    }

    private func checkForUpdatesIfNeeded() async {
        guard !hasCheckedForUpdates,
              model.settings.checksUpdatesOnLaunch else {
            return
        }
        hasCheckedForUpdates = true

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: Bundle.main.appReleaseVersion
            )
            guard result.hasUpdate else { return }
            updateAlert = DesktopAutomaticUpdateAlert(
                message: L10n.format(
                    "ui.update.available.message",
                    result.currentVersion,
                    result.latestVersion
                ),
                releaseURL: result.releaseURL
            )
        } catch {
            // Automatic checks should never block launching the player.
        }
    }
}

private struct DesktopAutomaticUpdateAlert: Identifiable {
    let id = UUID()
    let message: String
    let releaseURL: URL
}

private extension NeteaseMusicLink {
    var promptTitle: String {
        switch self {
        case .song: L10n.string("ui.clipboard.song_link_found")
        case .listenTogether: L10n.string("ui.clipboard.listen_together_found")
        }
    }

    var promptMessage: String {
        switch self {
        case .song: L10n.string("ui.clipboard.song_prompt")
        case .listenTogether:
            L10n.string("ui.clipboard.listen_together_prompt")
        }
    }

    var actionTitle: String {
        switch self {
        case .song: L10n.string("ui.clipboard.open_song")
        case .listenTogether: L10n.string("ui.clipboard.view_invitation")
        }
    }
}
