import SwiftUI

struct DesktopListenTogetherView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var invitationText: String
    @State private var confirmsLeaving = false

    init(invitationText: String = "") {
        _invitationText = State(initialValue: invitationText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.listen_together.title")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                if let operation = model.listenTogether.operation {
                    ProgressView()
                        .controlSize(.small)
                        .help(operation.title)
                }
                Button("ui.common.done") { dismiss() }
            }
            .padding(26)

            Divider()

            Group {
                if let room = model.listenTogether.room {
                    activeRoom(room)
                } else {
                    inactiveRoom
                }
            }
            .disabled(model.listenTogether.isBusy)
        }
        .frame(width: 620, height: 620)
        .alert(
            L10n.string("ui.listen_together.error.title"),
            isPresented: Binding(
                get: { model.listenTogether.errorMessage != nil },
                set: { if !$0 { model.listenTogether.dismissError() } }
            )
        ) {
            Button("ui.common.ok") { model.listenTogether.dismissError() }
        } message: {
            Text(model.listenTogether.errorMessage ?? L10n.string("ui.error.netease_operation_incomplete"))
        }
        .confirmationDialog(
            model.listenTogether.isHost
                ? L10n.string("ui.listen_together.end.confirmation")
                : L10n.string("ui.listen_together.leave.confirmation"),
            isPresented: $confirmsLeaving
        ) {
            Button(
                model.listenTogether.isHost
                    ? L10n.string("ui.listen_together.end")
                    : L10n.string("ui.listen_together.leave"),
                role: .destructive
            ) {
                Task { await model.listenTogether.leaveRoom() }
            }
        }
    }

    private var inactiveRoom: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 38)

                VStack(spacing: 8) {
                    Text("ui.listen_together.welcome.title")
                        .font(.title.bold())
                    Text("ui.desktop.listen_together.welcome.message")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if model.library.isLoggedIn {
                    Button {
                        Task { await model.listenTogether.createRoom() }
                    } label: {
                        Label("ui.listen_together.start", systemImage: "person.2.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.player.currentSong == nil)

                    if model.player.currentSong == nil {
                        Text("ui.error.listen_together.song_required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ui.listen_together.join_room")
                            .font(.headline)
                        TextField(
                            "ui.listen_together.paste_invitation",
                            text: $invitationText,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                        Button("ui.listen_together.join_room") {
                            Task {
                                await model.listenTogether.joinRoom(
                                    invitationText: invitationText
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(invitationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(18)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
                } else {
                    ContentUnavailableView {
                        Label("ui.listen_together.login_required", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("ui.listen_together.login_message")
                    } actions: {
                        Button("ui.common.login") { model.ui.sheet = .login }
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 36)
        }
    }

    private func activeRoom(_ room: ListenTogetherRoom) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: model.listenTogether.connectionState.systemImage)
                        .foregroundStyle(model.listenTogether.connectionState == .connected ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.listenTogether.connectionState.title)
                            .font(.headline)
                        Text(
                            model.listenTogether.isHost
                                ? L10n.string("ui.desktop.listen_together.your_room")
                                : L10n.string("ui.desktop.listen_together.friends_room")
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.listenTogether.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                if let song = model.player.currentSong {
                    HStack(spacing: 14) {
                        DesktopArtworkView(url: song.album?.artworkURL, cornerRadius: 8)
                            .frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ui.listen_together.syncing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(song.name)
                                .font(.title3.bold())
                            Text(song.artistText)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("ui.listen_together.room_members")
                        .font(.headline)
                    ForEach(room.users) { user in
                        HStack(spacing: 10) {
                            DesktopArtworkView(url: user.avatarURL, cornerRadius: 999)
                                .frame(width: 40, height: 40)
                                .clipShape(.circle)
                            Text(user.nickname)
                            if user.id == room.creatorID {
                                Text("ui.listen_together.host")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.12), in: .capsule)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                    }
                }

                HStack {
                    if let url = model.listenTogether.invitationURL {
                        ShareLink(item: url) {
                            Label("ui.listen_together.invite_friends", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(
                        model.listenTogether.isHost
                            ? L10n.string("ui.listen_together.end")
                            : L10n.string("ui.listen_together.leave"),
                        role: .destructive
                    ) {
                        confirmsLeaving = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(28)
        }
    }
}
