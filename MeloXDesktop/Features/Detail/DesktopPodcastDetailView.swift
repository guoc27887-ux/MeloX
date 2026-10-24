import SwiftUI

struct DesktopPodcastDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let podcastID: Int

    @State private var podcast: Podcast?
    @State private var programs: [PodcastProgram] = []
    @State private var order: PodcastProgramOrder = .newest
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var totalProgramCount = 0
    @State private var nextProgramOffset = 0
    @State private var hasMorePrograms = false
    @State private var isLoadingMorePrograms = false
    @State private var loadMoreProgramsError: String?

    private let programPageSize = 30

    var body: some View {
        let playbackSongs = programs.compactMap(\.playbackSong)

        Group {
            if let podcast {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        DesktopCollectionHeader(
                            artworkURL: podcast.artworkURL,
                            kind: L10n.string("ui.podcasts.podcast"),
                            title: podcast.name,
                            subtitle: podcast.host?.nickname,
                            metadata: metadata(for: podcast),
                            description: podcast.podcastDescription,
                            songs: playbackSongs,
                            sourceID: podcast.id,
                            isFavorite: model.library.contains(podcast: podcast),
                            favoriteAction: {
                                model.library.toggle(podcast: podcast)
                            },
                            shareURL: URL(
                                string: "https://music.163.com/#/djradio?id=\(podcast.id)"
                            )
                        )

                        HStack {
                            DesktopSectionHeader(title: L10n.string("ui.podcasts.episodes"))
                            Spacer()
                            Picker("ui.podcasts.episode_order", selection: $order) {
                                ForEach(PodcastProgramOrder.allCases) { order in
                                    Text(order.title).tag(order)
                                }
                            }
                            .frame(width: 150)
                        }

                        if programs.isEmpty {
                            programEmptyState
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(playbackSongs.enumerated()), id: \.element.id) { index, song in
                                    let row = DesktopTrackRow(
                                        song: song,
                                        index: index,
                                        songs: playbackSongs,
                                        sourceID: podcast.id,
                                        showsArtwork: true
                                    )

                                    if song.id == playbackSongs.last?.id,
                                       hasMorePrograms {
                                        row.task(id: nextProgramOffset) {
                                            await loadMorePrograms()
                                        }
                                    } else {
                                        row
                                    }
                                }
                            }

                            if hasMorePrograms {
                                DesktopCollectionPaginationFooter(
                                    isLoading: isLoadingMorePrograms,
                                    failureMessage: loadMoreProgramsError,
                                    loadingTitle: L10n.string("ui.podcasts.loading_more_episodes")
                                ) {
                                    await loadMorePrograms()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.podcasts.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load(reset: true) }
                }
            }
        }
        .navigationTitle(podcast?.name ?? L10n.string("ui.podcasts.podcast"))
        .task(id: loadRequest) { await load(reset: true) }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
    }

    private var loadRequest: DesktopPodcastDetailLoadRequest {
        DesktopPodcastDetailLoadRequest(
            podcastID: podcastID,
            order: order.rawValue
        )
    }

    private func metadata(for podcast: Podcast) -> String {
        let programCount = max(totalProgramCount, podcast.programCount)
        return L10n.format(
            "ui.desktop.podcasts.metadata",
            programCount,
            podcast.subscriberCount.formatted(.number.locale(L10n.locale))
        )
    }

    @ViewBuilder
    private var programEmptyState: some View {
        if isLoading {
            ProgressView("ui.podcasts.loading_episodes")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("ui.desktop.podcasts.load_episodes_failed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("ui.common.retry") {
                    Task { await load(reset: true) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ContentUnavailableView("ui.podcasts.no_episodes", systemImage: "waveform")
                .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private func load(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
            loadMoreProgramsError = nil
            nextProgramOffset = 0
            hasMorePrograms = false
            programs = []
        }
        defer {
            if reset {
                isLoading = false
            }
        }

        do {
            if reset {
                podcast = try await model.api.podcast(id: podcastID)
            }

            let requestedOffset = reset ? 0 : nextProgramOffset
            let page = try await model.api.podcastPrograms(
                radioID: podcastID,
                offset: requestedOffset,
                limit: programPageSize,
                ascending: order.ascending
            )
            try Task.checkCancellation()

            if reset {
                programs = page.programs
            } else {
                appendUnique(page.programs)
            }
            totalProgramCount = page.totalCount
            nextProgramOffset = requestedOffset + page.programs.count
            hasMorePrograms = page.hasMore && !page.programs.isEmpty
        } catch is CancellationError {
            return
        } catch {
            if reset {
                programs = []
                errorMessage = error.localizedDescription
            } else {
                loadMoreProgramsError = error.localizedDescription
            }
        }
    }

    private func loadMorePrograms() async {
        guard hasMorePrograms, !isLoadingMorePrograms else { return }
        isLoadingMorePrograms = true
        loadMoreProgramsError = nil
        defer { isLoadingMorePrograms = false }
        await load(reset: false)
    }

    private func appendUnique(_ newPrograms: [PodcastProgram]) {
        var loadedIDs = Set(programs.map(\.id))
        programs.append(
            contentsOf: newPrograms.filter {
                loadedIDs.insert($0.id).inserted
            }
        )
    }
}

private struct DesktopPodcastDetailLoadRequest: Hashable {
    let podcastID: Int
    let order: String
}
