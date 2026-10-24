import SwiftUI

struct PodcastDetailContent: View {
    let podcast: Podcast
    let programs: [PodcastProgram]
    let totalProgramCount: Int
    let searchQuery: String
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let isLoading: Bool
    let failureMessage: String?
    let hasMorePrograms: Bool
    let isLoadingMorePrograms: Bool
    let loadMoreProgramsError: String?
    let isSubscribing: Bool
    let onPlay: () -> Void
    let onToggleSubscription: () -> Void
    let onPlayProgram: (PodcastProgram) -> Void
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    PodcastDetailHero(
                        podcast: podcast,
                        programs: programs,
                        isSubscribing: isSubscribing,
                        onPlay: onPlay,
                        onToggleSubscription:
                            onToggleSubscription
                    )

                    if let description = podcast
                        .podcastDescription?
                        .podcastNonempty {
                        ExpandablePodcastDescription(
                            description: description
                        )
                        .padding(.bottom, 24)
                    }

                    PodcastProgramContent(
                        programs: filteredPrograms,
                        programCount: resolvedProgramCount,
                        emptyTitle: emptyProgramTitle,
                        isLoading: isLoading,
                        failureMessage: failureMessage,
                        hasMorePrograms: hasMorePrograms,
                        isLoadingMorePrograms:
                            isLoadingMorePrograms,
                        loadMoreProgramsError:
                            loadMoreProgramsError,
                        onPlay: onPlayProgram,
                        onRetry: onRetry,
                        onLoadMore: onLoadMore
                    )
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
        }
        .foregroundStyle(.primary)
    }

    private var resolvedProgramCount: Int {
        max(
            totalProgramCount,
            max(podcast.programCount, programs.count)
        )
    }

    private var filteredPrograms: [PodcastProgram] {
        guard let query = searchQuery.podcastNonempty else {
            return programs
        }
        return programs.filter { program in
            program.name.localizedCaseInsensitiveContains(query)
                || program.radio.name
                    .localizedCaseInsensitiveContains(query)
                || (
                    program.programDescription?
                        .localizedCaseInsensitiveContains(query)
                    ?? false
                )
        }
    }

    private var emptyProgramTitle: String {
        searchQuery.podcastNonempty == nil
            ? L10n.string("ui.podcasts.no_episodes")
            : L10n.string("ui.podcasts.no_matching_episodes")
    }
}

private struct PodcastDetailHero: View {
    let podcast: Podcast
    let programs: [PodcastProgram]
    let isSubscribing: Bool
    let onPlay: () -> Void
    let onToggleSubscription: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ArtworkImage(
                url: podcast.artworkURL,
                cornerRadius: 12
            )
            .containerRelativeFrame(.horizontal) { width, _ in
                min(width * 0.68, 300)
            }
            .shadow(
                color: .black.opacity(0.18),
                radius: 18,
                y: 10
            )

            Text(podcast.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text(podcast.host?.nickname ?? L10n.string("ui.service.netease_cloud_music"))
                .font(.title3)
                .lineLimit(1)
                .padding(.top, 8)

            if !metadataText.isEmpty {
                Text(metadataText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 7)
            }

            PodcastPrimaryActions(
                canPlay: programs.contains {
                    $0.playbackSong != nil
                },
                isSubscribed: podcast.isSubscribed,
                isSubscribing: isSubscribing,
                onPlay: onPlay,
                onToggleSubscription:
                    onToggleSubscription
            )
            .padding(.top, 17)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }

    private var metadataText: String {
        var values: [String] = []
        if podcast.programCount > 0 {
            values.append(L10n.format("ui.podcasts.episode_count", podcast.programCount))
        }
        if podcast.subscriberCount > 0 {
            values.append(
                L10n.format("ui.podcasts.subscriber_count", podcast.subscriberCount.podcastCountText)
            )
        }
        if podcast.playCount > 0 {
            values.append(
                L10n.format("ui.podcasts.play_count", podcast.playCount.podcastCountText)
            )
        }
        return L10n.joined(
            values,
            separatorKey: "ui.common.metadata_separator"
        )
    }
}

private struct PodcastPrimaryActions: View {
    let canPlay: Bool
    let isSubscribed: Bool
    let isSubscribing: Bool
    let onPlay: () -> Void
    let onToggleSubscription: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button(action: onPlay) {
                    Label("ui.common.play", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(minWidth: 116)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(primaryActionBackground)
                .foregroundStyle(primaryActionForeground)
                .disabled(!canPlay)

                Button(action: onToggleSubscription) {
                    Group {
                        if isSubscribing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(
                                systemName:
                                    isSubscribed
                                    ? "checkmark"
                                    : "plus"
                            )
                            .font(.title2.weight(.semibold))
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(isSubscribing)
                .accessibilityLabel(
                    isSubscribed
                        ? L10n.string("ui.common.unsubscribe")
                        : L10n.string("ui.podcasts.subscribe")
                )
            }
        }
    }

    private var primaryActionBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var primaryActionForeground: Color {
        colorScheme == .dark ? .black : .white
    }
}

private struct PodcastProgramContent: View {
    let programs: [PodcastProgram]
    let programCount: Int
    let emptyTitle: String
    let isLoading: Bool
    let failureMessage: String?
    let hasMorePrograms: Bool
    let isLoadingMorePrograms: Bool
    let loadMoreProgramsError: String?
    let onPlay: (PodcastProgram) -> Void
    let onRetry: () -> Void
    let onLoadMore: () async -> Void

    @Environment(PlayerStore.self) private var player

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.podcasts.episodes")
                    .font(.title3.bold())

                Spacer()

                if programCount > 0 {
                    Text(L10n.format("ui.podcasts.episode_count_short", programCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Group {
                if isLoading {
                    ProgressView("ui.podcasts.loading_episodes")
                        .tint(.primary)
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 180
                        )
                } else if let failureMessage {
                    ConnectionUnavailableView(
                        message: failureMessage,
                        retry: onRetry
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 220
                    )
                } else if programs.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage:
                            emptyTitle == L10n.string("ui.podcasts.no_episodes")
                            ? "waveform"
                            : "magnifyingglass"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 180
                    )
                } else {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(programs) { program in
                            PodcastProgramListRow(
                                program: program,
                                isCurrent: isCurrent(program),
                                isPlaying: player.isPlaying
                            ) {
                                onPlay(program)
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 8)
                            .padding(.vertical, 8)
                            .background(
                                isCurrent(program)
                                    ? Color.primary.opacity(0.10)
                                    : .clear
                            )

                            if program.id != programs.last?.id {
                                Divider()
                                    .overlay(
                                        Color.primary.opacity(0.12)
                                    )
                                    .padding(.leading, 105)
                                    .padding(.trailing, 20)
                            }
                        }

                        if hasMorePrograms {
                            MusicCollectionPaginationFooter(
                                isLoading:
                                    isLoadingMorePrograms,
                                failureMessage:
                                    loadMoreProgramsError,
                                loadToken: programs.count,
                                loadingTitle:
                                    L10n.string("ui.podcasts.loading_more_episodes"),
                                action: onLoadMore
                            )
                        }
                    }
                }
            }
        }
        .transition(.opacity)
        .animation(
            .easeInOut(duration: 0.2),
            value: isLoading
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: failureMessage
        )
    }

    private func isCurrent(
        _ program: PodcastProgram
    ) -> Bool {
        guard let song = program.playbackSong else {
            return false
        }
        return player.currentSong?.id == song.id
    }
}

private struct ExpandablePodcastDescription: View {
    let description: String

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Text(
                "\(description)  \(Text(isExpanded ? L10n.string("ui.common.collapse") : L10n.string("ui.common.more")).bold())"
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel(
            isExpanded
                ? L10n.string("ui.podcasts.collapse_description")
                : L10n.string("ui.podcasts.expand_description")
        )
    }
}
