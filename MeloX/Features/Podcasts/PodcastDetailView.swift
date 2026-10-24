import SwiftUI

struct PodcastDetailView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    @State private var podcast: Podcast
    @State private var programs: [PodcastProgram] = []
    @State private var phase: LoadingPhase = .loading
    @State private var order: PodcastProgramOrder = .newest
    @State private var totalProgramCount = 0
    @State private var hasMorePrograms = false
    @State private var isLoadingMore = false
    @State private var loadMoreError: String?
    @State private var isSubscribing = false
    @State private var subscriptionError: String?
    @State private var reloadToken = 0
    @State private var searchQuery = ""
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?

    private let pageSize = 30

    init(podcast: Podcast) {
        let cachedAssets =
            ArtworkAccentColorProvider.cachedDetailAssets(
                for: podcast.artworkURL
            )
        _podcast = State(initialValue: podcast)
        _artworkPalette = State(
            initialValue: cachedAssets?.palette
        )
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    var body: some View {
        PodcastDetailContent(
            podcast: podcast,
            programs: programs,
            totalProgramCount: totalProgramCount,
            searchQuery: searchQuery,
            palette: resolvedPalette,
            blurredBackdropImage: blurredBackdropImage,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            hasMorePrograms: hasMorePrograms,
            isLoadingMorePrograms: isLoadingMore,
            loadMoreProgramsError: loadMoreError,
            isSubscribing: isSubscribing,
            onPlay: playFirstProgram,
            onToggleSubscription: toggleSubscription,
            onPlayProgram: play,
            onRetry: { reloadToken += 1 },
            onRefresh: { await load(reset: true) },
            onLoadMore: { await loadMore() }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement:
                .navigationBarDrawer(displayMode: .always),
            prompt: Text("ui.podcasts.search_prompt")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(
            interfaceColorScheme,
            for: .navigationBar,
            .tabBar
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("ui.podcasts.episode_order", selection: $order) {
                        ForEach(PodcastProgramOrder.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("ui.podcasts.episode_order")
            }
        }
        .environment(\.colorScheme, interfaceColorScheme)
        .task(
            id: PodcastDetailLoadRequest(
                order: order,
                reloadToken: reloadToken
            )
        ) {
            await load(reset: true)
        }
        .task(id: artworkURL) {
            let transitionDelay = navigationTransitionDelay()
            defer { transitionDelay.cancel() }

            let loadedAssets =
                await ArtworkAccentColorProvider.shared
                    .detailAssets(
                        for: artworkURL,
                        fallbackPrefersDarkAppearance:
                            systemColorScheme == .dark
                    )
            guard !Task.isCancelled else { return }
            let backdropAlreadyResolved =
                blurredBackdropImage != nil
                || loadedAssets.blurredBackdropImage == nil
            if artworkPalette == loadedAssets.palette,
               backdropAlreadyResolved {
                return
            }
            do {
                try await transitionDelay.value
            } catch {
                return
            }
            withAnimation(artworkTransitionAnimation) {
                artworkPalette = loadedAssets.palette
                blurredBackdropImage =
                    loadedAssets.blurredBackdropImage
            }
        }
        .alert(
            "ui.podcasts.subscription_failed",
            isPresented: Binding(
                get: { subscriptionError != nil },
                set: {
                    if !$0 {
                        subscriptionError = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                subscriptionError = nil
            }
        } message: {
            Text(subscriptionError ?? L10n.string("ui.error.try_again_later"))
        }
    }

    private var artworkURL: URL? {
        podcast.artworkURL
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(
                prefersDarkAppearance:
                    systemColorScheme == .dark
            )
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var artworkTransitionAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .easeOut(duration: 0.18)
    }

    private var isInitialLoading: Bool {
        guard programs.isEmpty else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard programs.isEmpty,
              case .failed(let message) = phase else {
            return nil
        }
        return message
    }

    private var playbackSongs: [Song] {
        programs.compactMap(\.playbackSong)
    }

    private func playFirstProgram() {
        guard let first = playbackSongs.first else { return }
        Task {
            await player.play(
                first,
                in: playbackSongs,
                sourceID: podcast.id
            )
        }
    }

    private func play(_ program: PodcastProgram) {
        guard let song = program.playbackSong else { return }
        if player.currentSong?.id == song.id {
            player.togglePlayback()
            return
        }

        Task {
            await player.play(
                song,
                in: playbackSongs,
                sourceID: podcast.id
            )
        }
    }

    private func toggleSubscription() {
        guard library.isLoggedIn else {
            subscriptionError = L10n.string("ui.podcasts.login_to_subscribe")
            return
        }
        guard !isSubscribing else { return }

        let desiredState = !podcast.isSubscribed
        isSubscribing = true
        Task {
            defer { isSubscribing = false }
            do {
                try await library.setPodcastSubscribed(
                    podcast,
                    isSubscribed: desiredState
                )
                podcast.isSubscribed = desiredState
            } catch is CancellationError {
                return
            } catch {
                subscriptionError = error.localizedDescription
            }
        }
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            loadMoreError = nil
        }

        async let loadedPodcast =
            reset ? try? api.podcast(id: podcast.id) : nil

        do {
            let page = try await api.podcastPrograms(
                radioID: podcast.id,
                offset: reset ? 0 : programs.count,
                limit: pageSize,
                ascending: order.ascending
            )
            let refreshedPodcast = await loadedPodcast
            try Task.checkCancellation()

            if let refreshedPodcast {
                podcast = refreshedPodcast
            }
            if reset {
                programs = page.programs
            } else {
                appendUnique(page.programs)
            }
            totalProgramCount = page.totalCount
            hasMorePrograms = page.hasMore
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            if let refreshedPodcast = await loadedPodcast {
                podcast = refreshedPodcast
            }
            if reset {
                phase = .failed(error.localizedDescription)
            } else {
                loadMoreError = error.localizedDescription
            }
        }
    }

    private func loadMore() async {
        guard hasMorePrograms, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        await load(reset: false)
    }

    private func navigationTransitionDelay() -> Task<Void, Error> {
        Task {
            try await Task.sleep(
                for: MusicNavigationTransitionTiming.settleDelay
            )
        }
    }

    private func appendUnique(_ newPrograms: [PodcastProgram]) {
        var identifiers = Set(programs.map(\.id))
        programs.append(
            contentsOf: newPrograms.filter {
                identifiers.insert($0.id).inserted
            }
        )
    }
}

private struct PodcastDetailLoadRequest: Hashable {
    let order: PodcastProgramOrder
    let reloadToken: Int
}
