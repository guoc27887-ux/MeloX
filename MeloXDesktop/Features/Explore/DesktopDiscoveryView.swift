import SwiftUI

struct DesktopDiscoveryView: View {
    @Environment(DesktopAppModel.self) private var model

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                Text("ui.navigation.explore")
                    .font(.system(size: 32, weight: .bold))

                if !model.home.newSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        DesktopSectionHeader(title: L10n.string("ui.desktop.explore.new_songs"))
                        LazyVStack(spacing: 2) {
                            ForEach(Array(Array(model.home.newSongs.prefix(12)).enumerated()), id: \.element.id) {
                                index,
                                song in
                                DesktopTrackRow(
                                    song: song,
                                    index: index,
                                    songs: model.home.newSongs,
                                    showsArtwork: true
                                )
                            }
                        }
                    }
                }

                if !model.home.toplists.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        DesktopSectionHeader(title: L10n.string("ui.category.toplists"))
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(model.home.toplists) { playlist in
                                DesktopMediaCard(
                                    title: playlist.name,
                                    subtitle: playlist.updateFrequency,
                                    artworkURL: playlist.artworkURL,
                                    playCount: playlist.playCount,
                                    showsPlayCount: model.settings.showPlayCount,
                                    action: {
                                        model.ui.navigate(to: .playlist(playlist.id))
                                    },
                                    playAction: { play(playlist) }
                                )
                            }
                        }
                    }
                }

                if !model.home.topArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        DesktopSectionHeader(title: L10n.string("ui.desktop.explore.popular_artists"))
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(Array(model.home.topArtists.prefix(18))) { artist in
                                DesktopMediaCard(
                                    title: artist.name,
                                    subtitle: artist.aliases.first,
                                    artworkURL: artist.artworkURL,
                                    isCircular: true,
                                    action: {
                                        model.ui.navigate(to: .artist(artist.id))
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .navigationTitle("ui.navigation.explore")
        .task { await model.home.load() }
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(
                id: playlist.id,
                trackLimit: nil
            ) else { return }
            await model.player.playAll(detail.tracks, sourceID: detail.id)
        }
    }
}

struct DesktopRadioView: View {
    @Environment(DesktopAppModel.self) private var model

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                Text("ui.navigation.podcasts")
                    .font(.system(size: 32, weight: .bold))

                if !model.home.podcastCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        DesktopSectionHeader(title: L10n.string("ui.search.browse_categories"))
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(model.home.podcastCategories) { category in
                                    Button {
                                        model.ui.navigate(
                                            to: .podcastCategory(
                                                id: category.id,
                                                title: category.localizedName
                                            )
                                        )
                                    } label: {
                                        Label(
                                            category.localizedName,
                                            systemImage: "dot.radiowaves.left.and.right"
                                        )
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(.quaternary, in: .capsule)
                                        .contentShape(.capsule)
                                    }
                                    .buttonStyle(.plain)
                                    .help(
                                        L10n.format(
                                            "ui.desktop.podcasts.browse_category",
                                            category.localizedName
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                if !model.home.featuredPodcasts.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        DesktopSectionHeader(title: L10n.string("ui.podcasts.editors_choice"))
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(model.home.featuredPodcasts) { podcast in
                                DesktopMediaCard(
                                    title: podcast.name,
                                    subtitle: podcast.subtitle,
                                    artworkURL: podcast.artworkURL,
                                    action: {
                                        model.ui.navigate(to: .podcast(podcast.id))
                                    }
                                )
                            }
                        }
                    }
                }

                if !model.home.podcastPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        DesktopSectionHeader(title: L10n.string("ui.desktop.podcasts.latest_episodes"))
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.home.podcastPrograms.enumerated()), id: \.element.id) {
                                index,
                                program in
                                if let song = program.playbackSong {
                                    DesktopTrackRow(
                                        song: song,
                                        index: index,
                                        songs: model.home.podcastPrograms.compactMap(\.playbackSong),
                                        sourceID: program.radio.id,
                                        showsArtwork: true
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .navigationTitle("ui.navigation.podcasts")
        .task { await model.home.load() }
    }
}
