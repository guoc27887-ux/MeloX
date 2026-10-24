import SwiftUI

struct WatchMenuView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore

    let api: WatchNeteaseAPI

    var body: some View {
        List {
            Section("ui.settings.playback.section.playback") {
                NavigationLink {
                    WatchQueueView()
                        .navigationTitle("ui.player.queue")
                } label: {
                    Label("ui.player.queue", systemImage: "list.bullet")
                }

                Button {
                    coordinator.toggleShuffle()
                } label: {
                    Label(
                        coordinator.isShuffled
                            ? L10n.string("ui.player.shuffle_off")
                            : L10n.string("ui.player.shuffle_on"),
                        systemImage: "shuffle"
                    )
                }

                Button {
                    coordinator.cycleRepeatMode()
                } label: {
                    Label(
                        repeatTitle,
                        systemImage: coordinator.repeatMode == .one
                            ? "repeat.1"
                            : "repeat"
                    )
                }
            }

            Section("ui.watch.menu.discover") {
                NavigationLink {
                    WatchSearchView(api: api)
                } label: {
                    Label("ui.navigation.search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    WatchDailySongsView(api: api)
                } label: {
                    Label("ui.home.action.daily_songs", systemImage: "calendar")
                }

                NavigationLink {
                    WatchPlaylistsView(api: api)
                } label: {
                    Label("ui.watch.playlists.mine", systemImage: "music.note.list")
                }
            }

            Section("ui.watch.menu.account_device") {
                NavigationLink {
                    WatchAccountView(api: api)
                } label: {
                    Label(
                        account.profile?.nickname
                            ?? (account.isLoggedIn
                                ? L10n.string("ui.account.netease_account")
                                : L10n.string("ui.common.login")),
                        systemImage: account.isLoggedIn
                            ? "person.crop.circle.fill"
                            : "person.crop.circle.badge.plus"
                    )
                }

                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label("ui.watch.settings.title", systemImage: "gearshape")
                }

                Button {
                    connectivity.requestSnapshot()
                } label: {
                    Label(
                        "ui.watch.account.import_iphone",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            }
        }
        .navigationTitle("MeloX")
    }

    private var repeatTitle: String {
        switch coordinator.repeatMode {
        case .off: L10n.format("ui.watch.repeat.menu", L10n.string("ui.common.off"))
        case .all: L10n.format("ui.watch.repeat.menu", L10n.string("ui.watch.repeat.list"))
        case .one: L10n.format("ui.watch.repeat.menu", L10n.string("ui.watch.repeat.song"))
        }
    }
}
