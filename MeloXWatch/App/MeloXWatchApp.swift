import SwiftUI

@main
struct MeloXWatchApp: App {
    @AppStorage(AppLanguage.storageKey)
    private var appLanguage: AppLanguage = .system

    @StateObject private var account: WatchAccountStore
    @StateObject private var connectivity: WatchConnectivityStore
    @StateObject private var playback: WatchPlaybackStore
    @StateObject private var coordinator: WatchPlaybackCoordinator
    @StateObject private var lyrics: WatchLyricsStore

    private let api: WatchNeteaseAPI

    init() {
        WatchPreferenceDefaults.register()
        L10n.activate(AppLanguage.selected)

        let account = WatchAccountStore()
        let client = WatchNeteaseClient {
            account.cookie
        }
        let api = WatchNeteaseAPI(client: client)
        let connectivity = WatchConnectivityStore(
            accountStore: account
        )
        let playback = WatchPlaybackStore(api: api)
        let coordinator = WatchPlaybackCoordinator(
            standalone: playback
        )
        let lyrics = WatchLyricsStore(api: api)

        self.api = api
        _account = StateObject(wrappedValue: account)
        _connectivity = StateObject(wrappedValue: connectivity)
        _playback = StateObject(wrappedValue: playback)
        _coordinator = StateObject(wrappedValue: coordinator)
        _lyrics = StateObject(wrappedValue: lyrics)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(api: api)
                .environmentObject(account)
                .environmentObject(connectivity)
                .environmentObject(playback)
                .environmentObject(coordinator)
                .environmentObject(lyrics)
                .environment(\.locale, appLanguage.locale)
                .tint(.red)
                .onChange(of: appLanguage) { _, language in
                    L10n.activate(language)
                }
                .task {
                    connectivity.activate()
                }
        }
    }
}
