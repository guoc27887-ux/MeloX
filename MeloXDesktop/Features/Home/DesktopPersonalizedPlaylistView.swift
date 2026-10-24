import SwiftUI

enum DesktopPersonalizedPlaylistKind: Hashable {
    case dailySongs
    case privateRoaming
    case similarSongs(seedSongID: Int)

    var title: String {
        switch self {
        case .dailySongs: L10n.string("ui.home.action.daily_songs")
        case .privateRoaming: L10n.string("ui.home.action.private_roaming")
        case .similarSongs: L10n.string("ui.home.action.similar_songs")
        }
    }

    var systemImage: String {
        switch self {
        case .dailySongs: "calendar"
        case .privateRoaming: "figure.walk.motion"
        case .similarSongs: "music.note.list"
        }
    }

    var tint: Color {
        switch self {
        case .dailySongs: .red
        case .privateRoaming: .blue
        case .similarSongs: .teal
        }
    }

    var requiresLogin: Bool {
        switch self {
        case .dailySongs, .privateRoaming: true
        case .similarSongs: false
        }
    }

    var loadingMessage: String {
        switch self {
        case .dailySongs: L10n.string("ui.home.daily_songs.loading")
        case .privateRoaming: L10n.string("ui.desktop.home.private_roaming.loading")
        case .similarSongs: L10n.string("ui.desktop.home.similar_songs.loading")
        }
    }

    var emptyDescription: String {
        switch self {
        case .dailySongs:
            L10n.string("ui.desktop.home.daily_songs.empty")
        case .privateRoaming:
            L10n.string("ui.desktop.home.private_roaming.empty")
        case .similarSongs:
            L10n.string("ui.desktop.home.similar_songs.empty")
        }
    }
}

struct DesktopPersonalizedPlaylistView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: DesktopPersonalizedPlaylistKind

    @State private var songs: [Song] = []
    @State private var seedSong: Song?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            if kind.requiresLogin, !model.library.isLoggedIn {
                loginRequiredView
            } else {
                content
            }
        }
        .navigationTitle(kind.title)
        .task(id: loadRequest) {
            await load()
        }
        .alert(
            L10n.string("ui.home.daily_songs.refresh_failed"),
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { if !$0 { refreshErrorMessage = nil } }
            )
        ) {
            Button("ui.common.ok") { refreshErrorMessage = nil }
        } message: {
            Text(refreshErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: phase
        )
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            DesktopDetailLoadingView(message: kind.loadingMessage)
        case .failed(let message):
            DesktopDetailErrorView(message: message) {
                reloadToken += 1
            }
        case .loaded:
            playlistContent
        }
    }

    private var playlistContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                DesktopCollectionHeader(
                    artworkURL: artworkURL,
                    kind: L10n.string("ui.common.playlist"),
                    title: kind.title,
                    subtitle: subtitle,
                    metadata: metadata,
                    description: collectionDescription,
                    songs: songs,
                    sourceID: nil,
                    artworkSystemImage: artworkURL == nil
                        ? kind.systemImage
                        : nil,
                    artworkTint: kind.tint,
                    supplementaryAction: supplementaryAction
                )

                Divider()

                if songs.isEmpty {
                    ContentUnavailableView(
                        L10n.format("ui.desktop.home.no_personalized_songs", kind.title),
                        systemImage: kind.systemImage,
                        description: Text(kind.emptyDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    DesktopCollectionTrackList(
                        songs: songs,
                        sourceID: nil
                    )
                }
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 34)
        }
    }

    private var loginRequiredView: some View {
        ContentUnavailableView {
            Label(
                L10n.format("ui.desktop.home.sign_in_to_view", kind.title),
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
        } description: {
            Text("ui.desktop.home.account_generated_playlist")
        } actions: {
            Button("ui.account.login_netease") {
                model.ui.sheet = .login
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artworkURL: URL? {
        switch kind {
        case .dailySongs:
            nil
        case .privateRoaming:
            model.home.privateRadarPlaylist?.artworkURL
                ?? model.home.recommendedPlaylists.first?.artworkURL
        case .similarSongs:
            seedSong?.album?.artworkURL
        }
    }

    private var subtitle: String? {
        switch kind {
        case .dailySongs, .privateRoaming:
            L10n.string("ui.common.netease_cloud_music")
        case .similarSongs:
            if let seedSong {
                L10n.format("ui.desktop.home.based_on_song", seedSong.name)
            } else {
                L10n.string("ui.home.action.similar_songs.subtitle")
            }
        }
    }

    private var metadata: String {
        switch kind {
        case .dailySongs:
            L10n.format("ui.desktop.home.song_count_date", songs.count, todayText)
        case .privateRoaming:
            L10n.format("ui.desktop.home.song_count_personalized", songs.count)
        case .similarSongs:
            L10n.format("ui.common.song_count", songs.count)
        }
    }

    private var collectionDescription: String? {
        switch kind {
        case .dailySongs:
            return L10n.string("ui.desktop.home.daily_songs.description")
        case .privateRoaming:
            return L10n.string("ui.desktop.home.private_roaming.description")
        case .similarSongs:
            guard let seedSong else {
                return L10n.string("ui.desktop.home.similar_songs.description")
            }
            return L10n.format(
                "ui.desktop.home.similar_songs.seed_description",
                seedSong.artistText,
                seedSong.name
            )
        }
    }

    private var supplementaryAction: DesktopCollectionSupplementaryAction? {
        guard case .dailySongs = kind else { return nil }
        return DesktopCollectionSupplementaryAction(
            title: isRefreshing
                ? L10n.string("ui.home.daily_songs.refreshing")
                : L10n.string("ui.home.daily_songs.refresh"),
            systemImage: "arrow.triangle.2.circlepath",
            isRunning: isRefreshing,
            isDisabled: phase != .loaded,
            action: {
                Task { await refresh() }
            }
        )
    }

    private var todayText: String {
        Date.now.formatted(
            Date.FormatStyle(date: .long, time: .omitted).locale(L10n.locale)
        )
    }

    private var loadRequest: DesktopPersonalizedPlaylistLoadRequest {
        DesktopPersonalizedPlaylistLoadRequest(
            kind: kind,
            accountToken: model.settings.cookie.hashValue,
            reloadToken: reloadToken
        )
    }

    private func load() async {
        guard !kind.requiresLogin || model.library.isLoggedIn else {
            songs = []
            phase = .loaded
            return
        }

        phase = .loading
        do {
            let loadedSongs = try await fetchSongs(afresh: false)
            try Task.checkCancellation()
            guard !loadedSongs.isEmpty else {
                throw DesktopPersonalizedPlaylistError.emptyRecommendations(
                    kind.title
                )
            }
            songs = loadedSongs
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    private func refresh() async {
        guard !isRefreshing, case .dailySongs = kind else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshedSongs = try await fetchSongs(afresh: true)
            try Task.checkCancellation()
            guard !refreshedSongs.isEmpty else {
                throw DesktopPersonalizedPlaylistError.emptyRecommendations(
                    kind.title
                )
            }
            songs = refreshedSongs
        } catch is CancellationError {
            return
        } catch {
            refreshErrorMessage = error.localizedDescription
        }
    }

    private func fetchSongs(afresh: Bool) async throws -> [Song] {
        switch kind {
        case .dailySongs:
            return try await model.api.dailySongs(afresh: afresh)
        case .privateRoaming:
            return try await model.api.personalFM(
                mode: .explore,
                limit: 30
            )
        case .similarSongs(let seedSongID):
            if seedSong?.id != seedSongID {
                seedSong = model.player.currentSong?.id == seedSongID
                    ? model.player.currentSong
                    : try await model.api.songDetails(ids: [seedSongID]).first
            }
            return try await model.api.similarSongs(
                id: seedSongID,
                limit: 50
            )
        }
    }
}

private struct DesktopPersonalizedPlaylistLoadRequest: Hashable {
    let kind: DesktopPersonalizedPlaylistKind
    let accountToken: Int
    let reloadToken: Int
}

private enum DesktopPersonalizedPlaylistError: LocalizedError {
    case emptyRecommendations(String)

    var errorDescription: String? {
        switch self {
        case .emptyRecommendations(let title):
            L10n.format("ui.desktop.home.no_available_recommendations", title)
        }
    }
}
