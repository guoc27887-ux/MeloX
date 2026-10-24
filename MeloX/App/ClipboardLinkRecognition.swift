import SwiftUI
import UIKit

private enum ClipboardLinkOpenError: LocalizedError {
    case songNotFound

    var errorDescription: String? {
        switch self {
        case .songNotFound:
            L10n.string("ui.clipboard.error.song_not_found")
        }
    }
}

struct ClipboardLinkRecognitionModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(NeteaseAPI.self) private var api

    let onOpenSong: (Song) -> Void

    @State private var hasInspectedClipboardOnLaunch = false
    @State private var detectedLink: NeteaseMusicLink?
    @State private var listenTogetherInvitation:
        NeteaseListenTogetherLink?
    @State private var isOpeningSong = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .task {
                inspectClipboardOnLaunchIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                inspectClipboardOnLaunchIfNeeded()
            }
            .alert(
                detectedLink?.promptTitle ?? L10n.string("ui.clipboard.title"),
                isPresented: detectedLinkPresented
            ) {
                if let link = detectedLink {
                    Button(link.actionTitle) {
                        open(link)
                    }
                }
                Button("ui.common.ignore", role: .cancel) {}
            } message: {
                Text(
                    detectedLink?.promptMessage
                        ?? L10n.string("ui.clipboard.open_link_prompt")
                )
            }
            .sheet(item: $listenTogetherInvitation) { invitation in
                ListenTogetherView(
                    invitationText: invitation.invitationText
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert(
                "ui.clipboard.error.title",
                isPresented: errorPresented
            ) {
                Button("ui.common.ok", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? L10n.string("ui.error.try_again_later"))
            }
            .overlay {
                if isOpeningSong {
                    ProgressView("ui.clipboard.opening_song")
                        .padding()
                        .background(
                            .regularMaterial,
                            in: .rect(cornerRadius: 14)
                        )
                        .accessibilityLabel("ui.clipboard.opening_song_accessibility")
                }
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

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func inspectClipboardOnLaunchIfNeeded() {
        guard !hasInspectedClipboardOnLaunch,
              scenePhase == .active else {
            return
        }
        hasInspectedClipboardOnLaunch = true

        guard settings.recognizesClipboardLinksOnLaunch,
              let text = UIPasteboard.general.string,
              let link = NeteaseMusicLinkParser.parse(text) else {
            return
        }
        detectedLink = link
    }

    private func open(_ link: NeteaseMusicLink) {
        switch link {
        case .song(let id):
            openSong(id: id)
        case .listenTogether(let invitation):
            listenTogetherInvitation = invitation
        }
    }

    private func openSong(id: Int) {
        guard !isOpeningSong else { return }
        isOpeningSong = true

        Task {
            defer { isOpeningSong = false }
            do {
                let songs = try await api.songDetails(ids: [id])
                try Task.checkCancellation()
                guard let song = songs.first else {
                    throw ClipboardLinkOpenError.songNotFound
                }
                onOpenSong(song)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension NeteaseMusicLink {
    var promptTitle: String {
        switch self {
        case .song:
            L10n.string("ui.clipboard.song_link_found")
        case .listenTogether:
            L10n.string("ui.clipboard.listen_together_found")
        }
    }

    var promptMessage: String {
        switch self {
        case .song:
            L10n.string("ui.clipboard.song_prompt")
        case .listenTogether:
            L10n.string("ui.clipboard.listen_together_prompt")
        }
    }

    var actionTitle: String {
        switch self {
        case .song:
            L10n.string("ui.clipboard.open_song")
        case .listenTogether:
            L10n.string("ui.clipboard.view_invitation")
        }
    }
}

extension View {
    func recognizesClipboardLinksOnLaunch(
        onOpenSong: @escaping (Song) -> Void
    ) -> some View {
        modifier(
            ClipboardLinkRecognitionModifier(
                onOpenSong: onOpenSong
            )
        )
    }
}
