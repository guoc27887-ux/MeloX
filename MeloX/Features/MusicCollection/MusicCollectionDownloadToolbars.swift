import SwiftUI

struct MusicCollectionDownloadMenuContent: View {
    let coordinator: MusicCollectionDownloadCoordinator
    let downloadableSongCount: Int
    let onDownloadAll: (MusicQuality) -> Void

    var body: some View {
        Menu {
            ForEach(MusicQuality.allCases) { quality in
                Button(quality.title) {
                    onDownloadAll(quality)
                }
            }
        } label: {
            Label(
                L10n.format("ui.downloads.download_all_count", downloadableSongCount),
                systemImage: "arrow.down.circle"
            )
        }
        .disabled(
            downloadableSongCount == 0
                || coordinator.isPreparing
        )

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                coordinator.beginSelection()
            }
        } label: {
            Label("ui.common.select_multiple", systemImage: "checklist")
        }
        .disabled(
            downloadableSongCount == 0
                || coordinator.isPreparing
        )
    }
}

struct MusicCollectionDownloadSelectionToolbar: ToolbarContent {
    let coordinator: MusicCollectionDownloadCoordinator
    let downloadableSongIDs: [Int]
    let onDownloadSelection: (MusicQuality) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("ui.common.done") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coordinator.finishSelection()
                }
            }
            .disabled(coordinator.isPreparing)
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coordinator.toggleAll(
                        songIDs: Set(downloadableSongIDs)
                    )
                }
            } label: {
                Label(
                    hasSelectedAllDownloadableSongs
                        ? L10n.string("ui.common.deselect_all")
                        : L10n.string("ui.common.select_all"),
                    systemImage: hasSelectedAllDownloadableSongs
                        ? "checkmark.circle.fill"
                        : "checkmark.circle"
                )
            }
            .disabled(
                downloadableSongIDs.isEmpty
                    || coordinator.isPreparing
            )

            Spacer()

            if coordinator.isPreparing {
                ProgressView()
                    .accessibilityLabel(
                        L10n.format(
                            "ui.downloads.preparing_song_count",
                            coordinator.preparingSongCount
                        )
                    )
            } else {
                Menu {
                    ForEach(MusicQuality.allCases) { quality in
                        Button(quality.title) {
                            onDownloadSelection(quality)
                        }
                    }
                } label: {
                    Label(
                        L10n.format("ui.downloads.download_selected_count", selectedDownloadCount),
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(selectedDownloadCount == 0)
            }
        }
    }

    private var selectedDownloadCount: Int {
        coordinator.selectedSongIDs
            .intersection(downloadableSongIDs)
            .count
    }

    private var hasSelectedAllDownloadableSongs: Bool {
        let downloadableSongIDSet = Set(downloadableSongIDs)
        return !downloadableSongIDSet.isEmpty
            && downloadableSongIDSet.isSubset(
                of: coordinator.selectedSongIDs
            )
    }
}
