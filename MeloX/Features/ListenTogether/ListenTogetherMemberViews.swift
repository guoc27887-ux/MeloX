import SwiftUI

struct ListenTogetherMemberRows: View {
    let room: ListenTogetherRoom

    @ViewBuilder
    var body: some View {
        if room.users.isEmpty {
            Label(
                "ui.listen_together.loading_members",
                systemImage: "person.2"
            )
            .foregroundStyle(.secondary)
        } else {
            ForEach(room.users) { user in
                ListenTogetherMemberRow(
                    user: user,
                    isHost: user.id == room.creatorID
                )
            }
        }
    }
}

struct ListenTogetherMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ListenTogetherStore.self) private var listenTogether

    var body: some View {
        NavigationStack {
            List {
                if let room = listenTogether.room {
                    Section {
                        ListenTogetherMemberRows(room: room)
                    } header: {
                        Text(L10n.format("ui.listen_together.online_count", room.users.count))
                    }
                } else {
                    ContentUnavailableView(
                        "ui.listen_together.room_ended",
                        systemImage: "person.2.slash"
                    )
                }
            }
            .navigationTitle("ui.listen_together.members_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    invitationShareButton
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("ui.common.done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .frame(minWidth: 300, minHeight: 340)
    }

    @ViewBuilder
    private var invitationShareButton: some View {
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
        } else {
            Button(
                "ui.listen_together.invite_friends",
                systemImage: "square.and.arrow.up"
            ) {}
            .disabled(true)
            .accessibilityHint("ui.listen_together.no_shareable_song_hint")
        }
    }
}

private struct ListenTogetherMemberRow: View {
    let user: ListenTogetherUser
    let isHost: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(.quaternary, in: .circle)
            .clipShape(.circle)
            .accessibilityHidden(true)

            Text(user.nickname)
                .lineLimit(1)

            Spacer()

            if isHost {
                Text("ui.listen_together.host")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
