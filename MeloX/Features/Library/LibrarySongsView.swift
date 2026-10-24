import SwiftUI

struct LibrarySongsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player

    @State private var searchReloadToken = 0
    @State private var searchPreparationID: UUID?
    @State private var isStartingHeartMode = false
    @State private var heartModeErrorMessage: String?
    @State private var isPreparingPlayback = false
    @State private var playbackErrorMessage: String?

    var body: some View {
        List {
            if !displayedSongs.isEmpty {
                Button(action: playDisplayedSongs) {
                    HStack {
                        Label(
                            isSearching
                                ? L10n.string("ui.common.play_search_results")
                                : L10n.string("ui.common.play_all"),
                            systemImage: "play.fill"
                        )
                        Spacer()
                        if isPreparingPlayback {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isPreparingPlayback)

                if !isSearching {
                    heartModeButton
                }
            }

            ForEach(displayedSongs) { song in
                Button {
                    Task { await player.play(song, in: displayedSongs) }
                } label: {
                    TrackRowView(song: song, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        library.toggle(song: song)
                    } label: {
                        Label("ui.common.unfavorite", systemImage: "heart.slash")
                    }
                }
            }

            paginationFooter
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
            if isSearching {
                await prepareSearchResults(debounced: false)
            }
        }
        .overlay {
            emptyState
        }
        .task(
            id: LibrarySongSearchRequest(
                query: normalizedSearchQuery,
                reloadToken: searchReloadToken
            )
        ) {
            await prepareSearchResults(debounced: true)
        }
        .alert(
            "ui.library.heart_mode_failed",
            isPresented: Binding(
                get: { heartModeErrorMessage != nil },
                set: { presented in
                    if !presented {
                        heartModeErrorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                heartModeErrorMessage = nil
            }
        } message: {
            Text(heartModeErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
        .alert(
            "ui.library.play_all_failed",
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
            Text(playbackErrorMessage ?? L10n.string("ui.library.complete_song_list_failed"))
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var isPreparingSearchResults: Bool {
        searchPreparationID != nil
    }

    private var displayedSongs: [Song] {
        filterMusicCollectionTracks(
            library.favoriteSongs,
            query: normalizedSearchQuery
        )
    }

    private var heartModeButton: some View {
        Button(action: startHeartMode) {
            HStack {
                Label("ui.home.action.heart_mode", systemImage: "heart.circle.fill")
                Spacer()
                if isStartingHeartMode {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(!library.canStartHeartMode || isStartingHeartMode)
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isSearching {
            if isPreparingSearchResults {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("ui.library.searching_all_favorite_songs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .listRowSeparator(.hidden)
            } else if let failureMessage = library.favoriteSongsLoadMoreError,
                      library.hasMoreFavoriteSongs {
                VStack(spacing: 8) {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("ui.library.search_again") {
                        searchReloadToken += 1
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .listRowSeparator(.hidden)
            }
        } else if library.hasMoreFavoriteSongs {
            MusicCollectionPaginationFooter(
                isLoading: library.isLoadingMoreFavoriteSongs,
                failureMessage: library.favoriteSongsLoadMoreError,
                loadToken: library.favoriteSongsNextOffset,
                action: {
                    await library.loadMoreFavoriteSongs()
                }
            )
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if displayedSongs.isEmpty,
           !isPreparingSearchResults,
           !hasSearchLoadFailure {
            if isSearching {
                ContentUnavailableView.search(text: normalizedSearchQuery)
            } else if !library.hasMoreFavoriteSongs {
                ContentUnavailableView(
                    "ui.library.no_favorite_songs",
                    systemImage: "heart",
                    description: Text(
                        "ui.library.no_favorite_songs.message"
                    )
                )
            }
        }
    }

    private var hasSearchLoadFailure: Bool {
        isSearching
            && library.favoriteSongsLoadMoreError != nil
            && library.hasMoreFavoriteSongs
    }

    private func prepareSearchResults(debounced: Bool) async {
        guard isSearching else {
            searchPreparationID = nil
            return
        }

        guard library.hasMoreFavoriteSongs else { return }

        let preparationID = UUID()
        searchPreparationID = preparationID
        defer {
            if searchPreparationID == preparationID {
                searchPreparationID = nil
            }
        }

        if debounced {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        await library.loadRemainingFavoriteSongs()
    }

    private func startHeartMode() {
        guard !isStartingHeartMode,
              let playlistID = library.likedPlaylistID,
              let seedSongID = library.randomHeartModeSeedSongID() else {
            return
        }

        isStartingHeartMode = true
        heartModeErrorMessage = nil
        Task { @MainActor in
            defer { isStartingHeartMode = false }
            do {
                try await player.playHeartMode(
                    playlistID: playlistID,
                    seedSongID: seedSongID
                )
            } catch is CancellationError {
                return
            } catch {
                heartModeErrorMessage = error.localizedDescription
            }
        }
    }

    private func playDisplayedSongs() {
        guard !isPreparingPlayback else { return }
        isPreparingPlayback = true
        playbackErrorMessage = nil

        Task { @MainActor in
            defer { isPreparingPlayback = false }
            do {
                let songs = if isSearching {
                    displayedSongs
                } else {
                    try await library.favoriteSongsForPlayback()
                }
                try Task.checkCancellation()
                await player.playAll(songs)
            } catch is CancellationError {
                return
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct LibrarySongSearchRequest: Hashable {
    let query: String
    let reloadToken: Int
}
