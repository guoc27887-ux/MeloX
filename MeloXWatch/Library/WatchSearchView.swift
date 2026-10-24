import SwiftUI

struct WatchSearchView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    let api: WatchNeteaseAPI

    @State private var query = ""
    @State private var phase: WatchPagePhase<[WatchSong]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle:
                ContentUnavailableView(
                    "ui.watch.search.empty.title",
                    systemImage: "magnifyingglass",
                    description: Text("ui.watch.search.empty.description")
                )
            case .loading:
                ProgressView("ui.watch.search.searching")
            case .failed(let message):
                ContentUnavailableView(
                    "ui.watch.search.failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let songs):
                if songs.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(songs) { song in
                        Button {
                            Task {
                                await coordinator.play(song, in: songs)
                            }
                        } label: {
                            WatchSongLabel(song: song)
                        }
                    }
                }
            }
        }
        .navigationTitle("ui.navigation.search")
        .searchable(
            text: $query,
            prompt: Text("ui.watch.search.prompt")
        )
        .onSubmit(of: .search) {
            Task { await search() }
        }
    }

    private func search() async {
        let keywords = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !keywords.isEmpty else {
            phase = .idle
            return
        }
        phase = .loading
        do {
            phase = .loaded(try await api.searchSongs(keywords))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

struct WatchSongLabel: View {
    let song: WatchSong

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: song.album?.artworkURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(song.name)
                    .font(.body)
                    .lineLimit(1)
                Text(song.artistText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
