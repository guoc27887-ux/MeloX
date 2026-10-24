import SwiftUI

struct HeartModeNowPlayingBadge: View {
    @Environment(PlayerStore.self) private var player

    @State private var showsActions = false

    var body: some View {
        if player.isHeartModeActive {
            Button {
                showsActions = true
            } label: {
                Label("ui.home.action.heart_mode", systemImage: "heart.fill")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.14), in: .capsule)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("ui.heart_mode.active")
            .accessibilityHint("ui.heart_mode.manage_hint")
            .confirmationDialog(
                "ui.home.action.heart_mode",
                isPresented: $showsActions,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    player.disableHeartMode()
                } label: {
                    Label("ui.heart_mode.turn_off", systemImage: "heart.slash")
                }

                Button("ui.common.cancel", role: .cancel) {}
            } message: {
                Text("ui.heart_mode.turn_off_message")
            }
        }
    }
}
