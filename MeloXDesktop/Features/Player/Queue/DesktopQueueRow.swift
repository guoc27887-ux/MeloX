import SwiftUI

struct DesktopQueueRow: View {
    @Environment(DesktopAppModel.self) private var model

    let entry: DesktopQueueEntry
    let presentation: DesktopQueuePresentation
    let metrics: DesktopQueueMetrics

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: metrics.rowOuterSpacing) {
            Button(action: playEntry) {
                HStack(spacing: metrics.rowContentSpacing) {
                    DesktopArtworkView(
                        url: entry.song.album?.artworkURL,
                        cornerRadius: 5
                    )
                    .frame(
                        width: metrics.artworkSize,
                        height: metrics.artworkSize
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.song.name)
                            .font(metrics.rowTitleFont)
                            .lineLimit(1)
                        Text(metadataText)
                            .font(metrics.rowSubtitleFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Menu {
                Button("ui.common.play", systemImage: "play.fill") {
                    playEntry()
                }
                if entry.queueIndex != model.player.currentIndex {
                    Button(
                        "ui.desktop.player.remove_from_queue",
                        systemImage: "minus.circle",
                        role: .destructive
                    ) {
                        model.player.removeFromPlaybackQueue(
                            at: entry.queueIndex
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(menuColor)
                    .frame(
                        width: metrics.menuSize,
                        height: metrics.menuSize
                    )
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .tint(menuColor)
        }
        .onHover { isHovered = $0 }
    }

    private var metadataText: String {
        [entry.song.artistText, entry.song.album?.name]
            .compactMap { $0 }
            .joined(
                separator: L10n.string(
                    "ui.common.title_detail_separator"
                )
            )
    }

    private var menuColor: Color {
        switch presentation {
        case .nowPlaying:
            isHovered ? .red : .white.opacity(0.68)
        case .inspector, .miniPlayer:
            .primary
        }
    }

    private func playEntry() {
        Task {
            await model.player.playFromQueue(at: entry.queueIndex)
        }
    }
}
