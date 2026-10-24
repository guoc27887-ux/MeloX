import SwiftUI

struct ToplistsView: View {
    @Environment(NeteaseAPI.self) private var api

    @State private var playlists: [Playlist] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    private var officialToplists: [Playlist] {
        playlists.filter(\.isOfficialToplist)
    }

    private var globalToplists: [Playlist] {
        playlists.filter { !$0.isOfficialToplist }
    }

    var body: some View {
        Group {
            switch phase {
            case .loading where playlists.isEmpty:
                ProgressView("ui.toplists.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message) where playlists.isEmpty:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                content
            }
        }
        .navigationTitle("ui.toplists.title")
        .navigationBarTitleDisplayMode(.large)
        .task(id: reloadToken) {
            guard playlists.isEmpty else { return }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if playlists.isEmpty {
            ContentUnavailableView("ui.toplists.empty", systemImage: "chart.bar")
        } else {
            GeometryReader { proxy in
                let layout = MediaCardGridLayout(
                    containerWidth: proxy.size.width,
                    minimumItemWidth: 148
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        if officialToplists.isEmpty {
                            ToplistGridSection(
                                title: L10n.string("ui.toplists.all"),
                                playlists: playlists,
                                layout: layout
                            )
                        } else {
                            ToplistGridSection(
                                title: L10n.string("ui.toplists.official"),
                                playlists: officialToplists,
                                layout: layout
                            )

                            if !globalToplists.isEmpty {
                                ToplistGridSection(
                                    title: L10n.string("ui.toplists.global"),
                                    playlists: globalToplists,
                                    layout: layout
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await load()
                }
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            let loadedPlaylists = try await api.toplists()
            try Task.checkCancellation()
            playlists = loadedPlaylists
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct ToplistGridSection: View {
    let title: String
    let playlists: [Playlist]
    let layout: MediaCardGridLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.bold())

                Spacer()

                Text(L10n.format("ui.common.toplist_count", playlists.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: layout.columns,
                alignment: .leading,
                spacing: 22
            ) {
                ForEach(playlists) { playlist in
                    NavigationLink(value: MusicRoute.toplist(playlist)) {
                        MediaCardView(
                            title: playlist.name,
                            subtitle: playlist.updateFrequency ?? L10n.format("ui.common.song_count", playlist.trackCount),
                            artworkURL: playlist.artworkURL,
                            artworkSize: layout.itemWidth
                        )
                        .frame(width: layout.itemWidth)
                    }
                    .buttonStyle(.plain)
                    .musicMatchedTransitionSource(for: MusicRoute.toplist(playlist))
                    .accessibilityHint("ui.toplists.view_songs_hint")
                }
            }
        }
    }
}
