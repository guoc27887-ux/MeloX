import SwiftUI

struct ListenTogetherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var invitationText: String
    @State private var showsLeaveConfirmation = false

    init(invitationText: String = "") {
        _invitationText = State(initialValue: invitationText)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let room = listenTogether.room {
                    activeRoomContent(room)
                } else {
                    inactiveContent
                }
            }
            .navigationTitle("ui.listen_together.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ui.common.close") {
                        dismiss()
                    }
                    .disabled(listenTogether.operation == .leaving)
                }

                if let operation = listenTogether.operation {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                            .accessibilityLabel(operation.title)
                    }
                }
            }
            .disabled(listenTogether.isBusy)
            .confirmationDialog(
                listenTogether.isHost
                    ? L10n.string("ui.listen_together.end.confirmation")
                    : L10n.string("ui.listen_together.leave.confirmation"),
                isPresented: $showsLeaveConfirmation
            ) {
                Button(
                    listenTogether.isHost
                        ? L10n.string("ui.listen_together.end")
                        : L10n.string("ui.listen_together.leave"),
                    role: .destructive
                ) {
                    Task {
                        await listenTogether.leaveRoom()
                    }
                }
            } message: {
                Text(
                    listenTogether.isHost
                        ? L10n.string("ui.listen_together.end.message")
                        : L10n.string("ui.listen_together.leave.message")
                )
            }
            .alert(
                "ui.listen_together.error.title",
                isPresented: Binding(
                    get: { listenTogether.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            listenTogether.dismissError()
                        }
                    }
                )
            ) {
                Button("ui.common.ok", role: .cancel) {
                    listenTogether.dismissError()
                }
            } message: {
                Text(
                    listenTogether.errorMessage
                        ?? L10n.string("ui.error.netease_operation_incomplete")
                )
            }
        }
    }

    @ViewBuilder
    private var inactiveContent: some View {
        Section {
            VStack(spacing: 14) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("ui.listen_together.welcome.title")
                    .font(.title3.weight(.semibold))

                Text("ui.listen_together.welcome.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }

        if library.isLoggedIn {
            Section {
                Button {
                    Task {
                        await listenTogether.createRoom()
                    }
                } label: {
                    Label(
                        "ui.listen_together.start",
                        systemImage: "person.2.badge.plus"
                    )
                }
                .disabled(player.currentSong == nil)
            } header: {
                Text("ui.listen_together.create_room")
            } footer: {
                if player.currentSong == nil {
                    Text("ui.floating_lyrics.error.song_required")
                } else {
                    Text("ui.listen_together.create_room.message")
                }
            }

            Section {
                TextField(
                    "ui.listen_together.paste_invitation",
                    text: $invitationText,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    Task {
                        await listenTogether.joinRoom(
                            invitationText: invitationText
                        )
                    }
                } label: {
                    Label(
                        "ui.listen_together.join_room",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .disabled(
                    invitationText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            } header: {
                Text("ui.listen_together.join_room")
            } footer: {
                Text("ui.listen_together.invitation_requirements")
            }
        } else {
            Section {
                ContentUnavailableView {
                    Label(
                        "ui.listen_together.login_required",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                } description: {
                    Text("ui.listen_together.login_message")
                }
            }
        }
    }

    @ViewBuilder
    private func activeRoomContent(
        _ room: ListenTogetherRoom
    ) -> some View {
        Section("ui.player.now_playing") {
            if let song = player.currentSong {
                HStack(spacing: 12) {
                    songArtwork(song)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(song.artistText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 3)
                .accessibilityElement(children: .combine)
            } else {
                Label(
                    "ui.listen_together.waiting_for_playback",
                    systemImage: "music.note"
                )
                .foregroundStyle(.secondary)
            }
        }

        Section("ui.listen_together.room_sync") {
            ListenTogetherSyncStatusView()
        }

        Section {
            ListenTogetherMemberRows(room: room)
        } header: {
            Text("ui.listen_together.room_members")
        } footer: {
            Text(L10n.format("ui.listen_together.online_count", room.users.count))
        }

        Section {
            LabeledContent(L10n.string("ui.listen_together.room_id"), value: room.id)
                .textSelection(.enabled)

            if let invitationURL = listenTogether.invitationURL {
                ShareLink(
                    item: invitationURL,
                    subject: Text("ui.listen_together.share_subject"),
                    message: Text("ui.listen_together.share_message")
                ) {
                    Label(
                        "ui.listen_together.invite_friends",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        } header: {
            Text("ui.listen_together.invite")
        } footer: {
            Text("ui.listen_together.invite.footer")
        }

        Section {
            Button(
                listenTogether.isHost
                    ? L10n.string("ui.listen_together.end")
                    : L10n.string("ui.listen_together.leave"),
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive
            ) {
                showsLeaveConfirmation = true
            }
        }
    }

    private func songArtwork(_ song: Song) -> some View {
        AsyncImage(url: song.album?.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .background(.quaternary, in: .rect(cornerRadius: 8))
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

}
