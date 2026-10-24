import SwiftUI

struct WatchDailySongsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @EnvironmentObject private var account: WatchAccountStore

    let api: WatchNeteaseAPI

    @State private var phase: WatchPagePhase<[WatchSong]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                ProgressView("ui.common.loading")
            case .failed(let message):
                ContentUnavailableView(
                    "ui.watch.daily.load_failed",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(message)
                )
            case .loaded(let songs):
                List {
                    Button {
                        Task {
                            guard let first = songs.first else { return }
                            await coordinator.play(first, in: songs)
                        }
                    } label: {
                        Label("ui.action.play_all", systemImage: "play.fill")
                    }
                    .disabled(songs.isEmpty)

                    ForEach(songs) { song in
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
        .navigationTitle("ui.watch.daily.title")
        .task {
            await load()
        }
    }

    private func load() async {
        guard account.isLoggedIn else {
            phase = .failed(L10n.string("ui.watch.daily.login_required"))
            return
        }
        phase = .loading
        do {
            phase = .loaded(try await api.dailySongs())
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
