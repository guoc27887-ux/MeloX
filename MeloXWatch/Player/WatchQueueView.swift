import SwiftUI

struct WatchQueueView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    var body: some View {
        Group {
            if coordinator.queue.isEmpty {
                ContentUnavailableView(
                    "ui.watch.queue.empty.title",
                    systemImage: "list.bullet",
                    description: Text("ui.watch.queue.empty.description")
                )
            } else {
                ScrollViewReader { proxy in
                    List(coordinator.playbackOrderIndices, id: \.self) {
                        index in
                        if coordinator.queue.indices.contains(index) {
                            queueRow(
                                song: coordinator.queue[index],
                                index: index
                            )
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onChange(
                        of: queueScrollState,
                        initial: true
                    ) { _, state in
                        guard coordinator.queue.indices.contains(
                            state.currentIndex
                        ) else {
                            return
                        }
                        withAnimation(.smooth(duration: 0.25)) {
                            proxy.scrollTo(
                                state.currentIndex,
                                anchor: .center
                            )
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                playbackModeButton
            }
        }
    }

    private func queueRow(
        song: WatchSong,
        index: Int
    ) -> some View {
        Button {
            Task {
                await coordinator.playQueueItem(at: index)
            }
        } label: {
            HStack(spacing: 6) {
                WatchSongLabel(song: song)

                Spacer(minLength: 0)

                if index == coordinator.currentIndex {
                    Image(
                        systemName: coordinator.isPlaying
                            ? "waveform"
                            : "pause.fill"
                    )
                    .contentTransition(
                        .symbolEffect(.replace.downUp.wholeSymbol)
                    )
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .id(index)
        .accessibilityAddTraits(
            index == coordinator.currentIndex ? .isSelected : []
        )
        .listRowBackground(Color.clear)
    }

    private var queueScrollState: QueueScrollState {
        QueueScrollState(
            songIDs: coordinator.queue.map(\.id),
            playbackOrderIndices: coordinator.playbackOrderIndices,
            currentIndex: coordinator.currentIndex
        )
    }

    private var playbackModeButton: some View {
        Button(action: cyclePlaybackMode) {
            WatchCircularControlLabel(
                systemImage: playbackMode.systemImage,
                size: 34,
                iconScale: 0.42
            )
        }
        .buttonStyle(.plain)
        .tint(.white)
        .accessibilityLabel(
            L10n.format("ui.watch.queue.mode_accessibility", playbackMode.title)
        )
        .accessibilityHint(
            L10n.format(
                "ui.watch.queue.mode_hint",
                playbackMode.next.title
            )
        )
    }

    private var playbackMode: WatchQueuePlaybackMode {
        switch coordinator.repeatMode {
        case .one:
            return .repeatOne
        case .all:
            return .repeatAll
        case .off:
            return coordinator.isShuffled ? .shuffle : .sequential
        }
    }

    private func cyclePlaybackMode() {
        let nextMode = playbackMode.next
        withAnimation(.smooth(duration: 0.25)) {
            coordinator.setPlaybackMode(
                isShuffled: nextMode.isShuffled,
                repeatMode: nextMode.repeatMode
            )
        }
    }
}

private struct QueueScrollState: Equatable {
    let songIDs: [Int]
    let playbackOrderIndices: [Int]
    let currentIndex: Int
}

private enum WatchQueuePlaybackMode: CaseIterable {
    case sequential
    case shuffle
    case repeatAll
    case repeatOne

    var title: String {
        switch self {
        case .sequential: L10n.string("ui.watch.queue.mode.sequential")
        case .shuffle: L10n.string("ui.watch.queue.mode.shuffle")
        case .repeatAll: L10n.string("ui.watch.repeat.list")
        case .repeatOne: L10n.string("ui.watch.repeat.song")
        }
    }

    var systemImage: String {
        switch self {
        case .sequential: "arrow.right"
        case .shuffle: "shuffle"
        case .repeatAll: "repeat"
        case .repeatOne: "repeat.1"
        }
    }

    var isShuffled: Bool {
        self == .shuffle
    }

    var repeatMode: WatchRepeatMode {
        switch self {
        case .repeatAll: .all
        case .repeatOne: .one
        case .sequential, .shuffle: .off
        }
    }

    var next: Self {
        let modes = Self.allCases
        guard let index = modes.firstIndex(of: self) else {
            return .sequential
        }
        return modes[(index + 1) % modes.count]
    }
}
