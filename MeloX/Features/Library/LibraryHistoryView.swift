import SwiftUI

struct LibraryHistoryView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player

    var body: some View {
        List {
            if !displayedSongs.isEmpty {
                Button {
                    Task { await player.playAll(displayedSongs) }
                } label: {
                    Label(
                        isSearching
                            ? L10n.string("ui.common.play_search_results")
                            : L10n.string("ui.common.play_all"),
                        systemImage: "play.fill"
                    )
                }
            }

            ForEach(displayedSongs) { song in
                Button {
                    Task { await player.play(song, in: displayedSongs) }
                } label: {
                    TrackRowView(song: song, showsArtwork: true)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if displayedSongs.isEmpty {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else {
                    ContentUnavailableView(
                        "ui.library.no_history",
                        systemImage: "clock",
                        description: Text(
                            "ui.library.no_history.message"
                        )
                    )
                }
            }
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var displayedSongs: [Song] {
        filterMusicCollectionTracks(
            library.recentSongs,
            query: normalizedSearchQuery
        )
    }
}
