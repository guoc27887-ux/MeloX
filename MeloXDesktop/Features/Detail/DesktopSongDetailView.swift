import SwiftUI

private enum DesktopSongDetailTab: String, CaseIterable, Identifiable {
    case details
    case lyrics
    case comments

    var id: Self { self }

    var title: String {
        switch self {
        case .details: L10n.string("ui.song.detail.title")
        case .lyrics: L10n.string("ui.common.lyrics")
        case .comments: L10n.string("ui.comments.title")
        }
    }
}

struct DesktopSongDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    let songID: Int

    @State private var song: Song?
    @State private var lyrics: [LyricLine] = []
    @State private var similarSongs: [Song] = []
    @State private var comments: [SongComment] = []
    @State private var selectedTab: DesktopSongDetailTab = .details
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let song {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        DesktopCollectionHeader(
                            artworkURL: song.album?.artworkURL,
                            kind: song.isPodcastProgram
                                ? L10n.string("ui.podcasts.episode")
                                : L10n.string("ui.common.songs"),
                            title: song.name,
                            subtitle: song.artistText,
                            metadata: [song.album?.name, song.durationText]
                                .compactMap { $0 }
                                .joined(
                                    separator: L10n.string(
                                        "ui.common.metadata_separator"
                                    )
                                ),
                            description: song.aliases.isEmpty
                                ? song.podcastMetadata?.programDescription
                                : L10n.joined(
                                    song.aliases,
                                    separatorKey:
                                        "ui.common.metadata_separator"
                                ),
                            songs: [song],
                            sourceID: song.album?.id,
                            isFavorite: model.library.contains(song: song),
                            favoriteAction: { model.library.toggle(song: song) }
                        )

                        Picker("ui.desktop.song.content", selection: $selectedTab) {
                            ForEach(DesktopSongDetailTab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 420)

                        tabContent(song)
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.song.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load() }
                }
            }
        }
        .navigationTitle(song?.name ?? L10n.string("ui.common.songs"))
        .task(id: songID) { await load() }
    }

    @ViewBuilder
    private func tabContent(_ song: Song) -> some View {
        switch selectedTab {
        case .details:
            VStack(alignment: .leading, spacing: 18) {
                DesktopSectionHeader(title: L10n.string("ui.home.action.similar_songs"))
                DesktopCollectionTrackList(songs: similarSongs, sourceID: song.album?.id)
            }
        case .lyrics:
            if lyrics.isEmpty {
                ContentUnavailableView("ui.desktop.lyrics.unavailable", systemImage: "quote.bubble")
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(lyrics) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.text)
                                .font(.system(size: 22, weight: .bold))
                            if let translation = line.translation {
                                Text(translation)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            Task { await model.player.play(song, startAt: line.time) }
                        }
                    }
                }
            }
        case .comments:
            if comments.isEmpty {
                ContentUnavailableView("ui.comments.empty", systemImage: "bubble.left")
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(comments) { comment in
                        HStack(alignment: .top, spacing: 12) {
                            DesktopCircularArtworkView(url: comment.user.artworkURL)
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(comment.user.nickname)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(comment.timeDescription ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(comment.content)
                                    .textSelection(.enabled)
                                if comment.likedCount > 0 {
                                    Label(
                                        comment.likedCount.formatted(
                                            .number.locale(L10n.locale)
                                        ),
                                        systemImage: "hand.thumbsup"
                                    )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 13)
                        Divider()
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let loadedSong = try await model.api.songDetails(ids: [songID]).first else {
                throw APIError.invalidResponse
            }
            song = loadedSong
            async let loadedLyrics = model.lyrics.fetch(for: loadedSong)
            async let loadedSimilar = model.api.similarSongs(id: songID, limit: 20)
            async let loadedComments = model.api.songComments(id: songID, limit: 40)
            lyrics = (try? await loadedLyrics) ?? []
            similarSongs = (try? await loadedSimilar) ?? []
            if let response = try? await loadedComments {
                comments = response.hotComments + response.comments
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
