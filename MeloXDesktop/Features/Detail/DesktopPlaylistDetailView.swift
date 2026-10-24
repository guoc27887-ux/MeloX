import SwiftUI

struct DesktopPlaylistDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let playlistID: Int

    @State private var playlist: Playlist?
    @State private var pendingRemoval: Song?
    @State private var isRemovingTrack = false
    @State private var removalError: String?

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadedTrackOffset = 0
    @State private var isLoadingMoreTracks = false
    @State private var loadMoreTracksError: String?
    @State private var isPreparingPlayback = false
    @State private var playbackErrorMessage: String?

    private let trackPageSize = 100

    var body: some View {
        Group {
            if let playlist {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 34) {
                        DesktopCollectionHeader(
                            artworkURL: playlist.artworkURL,
                            kind: playlist.isOfficialToplist
                                ? L10n.string("ui.category.toplists")
                                : L10n.string("ui.common.playlist"),
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname,
                            metadata: metadata(for: playlist),
                            description: playlist.playlistDescription,
                            songs: songs,
                            sourceID: playlist.id,
                            isFavorite: model.library.contains(playlist: playlist),
                            favoriteAction: {
                                model.library.toggle(playlist: playlist)
                            },
                            shareURL: URL(
                                string: "https://music.163.com/#/playlist?id=\(playlist.id)"
                            ),
                            onPlayAll: { shuffled in
                                await playAll(shuffled: shuffled)
                            }
                        )

                        Divider()
                        DesktopCollectionTrackList(
                            songs: songs,
                            sourceID: playlist.id,
                            loadMoreToken: hasMoreTracks
                                ? loadedTrackOffset
                                : nil,
                            onLoadMore: {
                                await loadMoreTracks()
                            },
                            onRemoveSong: model.library.canDelete(playlist) && !isLoadingMoreTracks
                                ? { pendingRemoval = $0 }
                                : nil
                        )

                        if hasMoreTracks {
                            DesktopCollectionPaginationFooter(
                                isLoading: isLoadingMoreTracks,
                                failureMessage: loadMoreTracksError
                            ) {
                                await loadMoreTracks()
                            }
                        }
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.playlists.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load() }
                }
            }
        }
        .disabled(isRemovingTrack)
        .confirmationDialog(
            "ui.playlists.remove_song",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { song in
            Button("ui.playlists.remove_song", role: .destructive) {
                Task { await removeSong(song) }
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: { song in
            Text(L10n.format("ui.playlists.remove_song.message", song.name))
        }
        .alert("ui.library.error.title", isPresented: Binding(
            get: { removalError != nil },
            set: { if !$0 { removalError = nil } }
        )) {
            Button("ui.common.ok", role: .cancel) { removalError = nil }
        } message: {
            Text(removalError ?? "")
        }
        .navigationTitle(playlist?.name ?? L10n.string("ui.common.playlist"))
        .task(id: playlistID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
        .alert(
            L10n.string("ui.desktop.collection.play_all_failed"),
            isPresented: Binding(
                get: { playbackErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        playbackErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                playbackErrorMessage = nil
            }
        } message: {
            Text(playbackErrorMessage ?? L10n.string("ui.playlists.load_complete_failed"))
        }
    }

    private func metadata(for playlist: Playlist) -> String {
        var parts = [L10n.format("ui.common.song_count", playlist.trackCount)]
        if model.settings.showPlayCount {
            parts.append(L10n.format("ui.common.play_count", playlist.playCount))
        }
        return L10n.joined(
            parts,
            separatorKey: "ui.common.metadata_separator"
        )
    }

    private var hasMoreTracks: Bool {
        guard let playlist, !playlist.trackIDs.isEmpty else {
            return false
        }
        return loadedTrackOffset < playlist.trackIDs.count
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        loadedTrackOffset = 0
        loadMoreTracksError = nil
        do {
            let detail = try await model.api.playlist(
                id: playlistID,
                trackLimit: trackPageSize
            )
            try Task.checkCancellation()
            playlist = detail
            songs = detail.tracks
            loadedTrackOffset = min(
                trackPageSize,
                detail.trackIDs.count
            )
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeSong(_ song: Song) async {
        guard let playlist, !isLoadingMoreTracks else { return }
        isRemovingTrack = true
        defer { isRemovingTrack = false }
        do {
            try await model.library.remove(song: song, from: playlist)
            guard var updated = self.playlist else { return }
            if let index = updated.removeSong(id: song.id), index < loadedTrackOffset {
                loadedTrackOffset -= 1
            }
            self.playlist = updated
            songs.removeAll { $0.id == song.id }
        } catch {
            removalError = error.localizedDescription
        }
    }

    private func loadMoreTracks() async {
        guard let currentPlaylist = playlist,
              !isLoadingMoreTracks,
              !isRemovingTrack,
              loadedTrackOffset < currentPlaylist.trackIDs.count else {
            return
        }

        let requestedOffset = loadedTrackOffset
        let trackIDs = currentPlaylist.trackIDs.map(\.id)
        isLoadingMoreTracks = true
        loadMoreTracksError = nil
        defer { isLoadingMoreTracks = false }

        do {
            let page = try await model.api.songDetailsPage(
                ids: trackIDs,
                offset: requestedOffset,
                limit: trackPageSize
            )
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id,
                  loadedTrackOffset == requestedOffset else {
                return
            }

            var loadedIDs = Set(songs.map(\.id))
            songs.append(
                contentsOf: page.songs.filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            loadedTrackOffset = page.nextOffset
        } catch is CancellationError {
            return
        } catch {
            loadMoreTracksError = error.localizedDescription
        }
    }

    private func playAll(shuffled: Bool) async {
        guard let currentPlaylist = playlist,
              !isPreparingPlayback else {
            return
        }

        isPreparingPlayback = true
        playbackErrorMessage = nil
        defer { isPreparingPlayback = false }

        do {
            let trackIDs = currentPlaylist.trackIDs.map(\.id)
            let completeSongs = if trackIDs.isEmpty {
                songs
            } else {
                try await model.api.songDetailsCollection(
                    ids: trackIDs,
                    prefetched: songs
                )
            }
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id else { return }
            await model.player.playAll(
                shuffled ? completeSongs.shuffled() : completeSongs,
                sourceID: currentPlaylist.id
            )
        } catch is CancellationError {
            return
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
}
