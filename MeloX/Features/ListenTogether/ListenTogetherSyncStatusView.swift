import SwiftUI

struct ListenTogetherSyncStatusView: View {
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                statusIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)

                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(
                    listenTogether.isHost
                        ? L10n.string("ui.listen_together.host")
                        : L10n.string("ui.listen_together.participant")
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        statusColor.opacity(0.12),
                        in: .capsule
                    )
            }

            Divider()

            HStack(spacing: 12) {
                lastSyncLabel

                Spacer()

                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("ui.listen_together.syncing")
                    } else {
                        Label(
                            "ui.listen_together.sync_now",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshing)
            }
            .font(.footnote)
        }
        .padding(.vertical, 5)
        .animation(
            .default,
            value: listenTogether.connectionState
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.14))

            if listenTogether.connectionState == .reconnecting {
                ProgressView()
                    .tint(statusColor)
                    .controlSize(.small)
            } else {
                Image(systemName: statusSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var lastSyncLabel: some View {
        if let lastSyncDate = listenTogether.lastSyncDate {
            Label {
                HStack(spacing: 3) {
                    Text("ui.listen_together.last_sync")
                    Text(lastSyncDate, style: .relative)
                }
            } icon: {
                Image(systemName: "clock")
            }
            .foregroundStyle(.secondary)
        } else {
            Label(
                "ui.listen_together.waiting_first_sync",
                systemImage: "clock"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        switch listenTogether.connectionState {
        case .idle:
            L10n.string("ui.listen_together.preparing_sync")
        case .connected:
            L10n.string("ui.listen_together.playback_synchronized")
        case .reconnecting:
            L10n.string("ui.listen_together.restoring_connection")
        }
    }

    private var statusDetail: String {
        switch listenTogether.connectionState {
        case .idle:
            L10n.string("ui.listen_together.reading_playback_state")
        case .connected:
            L10n.string("ui.listen_together.sync_message")
        case .reconnecting:
            L10n.string("ui.listen_together.reconnect_message")
        }
    }

    private var statusSystemImage: String {
        switch listenTogether.connectionState {
        case .idle:
            "clock"
        case .connected:
            "checkmark"
        case .reconnecting:
            "arrow.clockwise"
        }
    }

    private var statusColor: Color {
        switch listenTogether.connectionState {
        case .idle:
            .secondary
        case .connected:
            .green
        case .reconnecting:
            .orange
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { @MainActor in
            await listenTogether.refresh()
            isRefreshing = false
        }
    }
}
