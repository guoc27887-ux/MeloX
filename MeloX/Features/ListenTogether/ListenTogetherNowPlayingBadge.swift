import SwiftUI

struct ListenTogetherNowPlayingBadge: View {
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var showsMembers = false

    var body: some View {
        if let room = listenTogether.room {
            Button {
                showsMembers = true
            } label: {
                Label("ui.listen_together.title", systemImage: "person.2.fill")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.14), in: .capsule)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel(
                L10n.format(
                    "ui.listen_together.member_count_accessibility",
                    room.users.count
                )
            )
            .accessibilityHint("ui.listen_together.view_members_hint")
            .popover(isPresented: $showsMembers) {
                ListenTogetherMembersView()
                    .presentationCompactAdaptation(.sheet)
            }
        }
    }
}
