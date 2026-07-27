import SwiftUI

struct ContentView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads
    @Environment(LyricsStore.self) private var lyrics
    @Environment(FloatingLyricsController.self) private var floatingLyrics

    @State private var selectedTab: AppTab
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var playerPresentation: PlayerPresentation?
    @State private var neteaseSharePresentation: NeteaseSharePresentation?
    @State private var nowPlayingSharePresentation: NeteaseSharePresentation?
    @State private var pendingMusicRoute: MusicRoute?
    @Namespace private var playerTransitionNamespace
    @Namespace private var musicNavigationNamespace

    private let playerTransitionID = "now-playing"

    init(initialTab: AppTab = .home) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                mainExperience
            } else {
                OnboardingView()
            }
        }
    }

    private var mainExperience: some View {
        playerAwareTabView
            .environment(
                \.openMusicRoute,
                OpenMusicRouteAction(action: openMusicRoute)
            )
            .environment(
                \.openNeteaseShare,
                OpenNeteaseShareAction(action: openNeteaseShare)
            )
            .fullScreenCover(
                item: $playerPresentation,
                onDismiss: finishPendingSongNavigation
            ) { destination in
                switch destination {
                case .nowPlaying:
                    NowPlayingView(initialPage: initialNowPlayingPage)
                        .environment(
                            \.openMusicRoute,
                            OpenMusicRouteAction(action: openMusicRoute)
                        )
                        .environment(
                            \.openNeteaseShare,
                            OpenNeteaseShareAction { presentation in
                                presentNeteaseShare(
                                    presentation,
                                    fromNowPlaying: true
                                )
                            }
                        )
                        .sheet(item: $nowPlayingSharePresentation) {
                            presentation in
                            NeteaseShareSheet(presentation: presentation)
                        }
                        .presentationBackground(.clear)
                        .navigationTransition(
                            .zoom(
                                sourceID: playerTransitionID,
                                in: playerTransitionNamespace
                            )
                        )
                }
            }
            .sheet(item: $neteaseSharePresentation) { presentation in
                NeteaseShareSheet(presentation: presentation)
            }
            .task {
                await player.restore()
            }
            .task(id: player.currentSong?.id) {
                let songID = player.currentSong?.id
                await lyrics.load(for: songID)
                guard !Task.isCancelled else { return }
                player.setNowPlayingLyrics(lyrics.lyrics, for: songID)
            }
            .task {
                await floatingLyrics.monitor()
            }
            .task(id: settings.cookie) {
                await library.refresh()
            }
            .background(alignment: .topLeading) {
                FloatingLyricsPictureInPictureSource(
                    controller: floatingLyrics
                )
                .frame(width: 2, height: 2)
                .opacity(0.01)
                .accessibilityHidden(true)
            }
            .onChange(of: selectedTab) { _, tab in
                settings.lastSelectedTab = tab
            }
            .onChange(of: floatingLyrics.restorationRequestID) {
                guard floatingLyrics.restorationRequestID > 0,
                      player.currentSong != nil else {
                    floatingLyrics.completeRestoration(success: false)
                    return
                }

                playerPresentation = .nowPlaying
                Task { @MainActor in
                    await Task.yield()
                    floatingLyrics.completeRestoration(success: true)
                }
            }
            .alert(
                "歌曲无法播放",
                isPresented: Binding(
                    get: { player.playbackIssue != nil },
                    set: { isPresented in
                        if !isPresented {
                            player.dismissPlaybackIssue()
                        }
                    }
                )
            ) {
                if player.canPlayNext {
                    Button("播放下一首") {
                        player.dismissPlaybackIssue()
                        Task { await player.next() }
                    }
                }
                Button("好", role: .cancel) {
                    player.dismissPlaybackIssue()
                }
            } message: {
                Text(player.playbackIssue?.message ?? "当前歌曲暂时无法播放。")
            }
            .alert(
                "下载操作失败",
                isPresented: Binding(
                    get: { downloads.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            downloads.clearError()
                        }
                    }
                )
            ) {
                Button("好", role: .cancel) {
                    downloads.clearError()
                }
            } message: {
                Text(downloads.errorMessage ?? "无法完成下载操作。")
            }
            .alert(
                "无法打开悬浮歌词",
                isPresented: Binding(
                    get: { floatingLyrics.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            floatingLyrics.dismissError()
                        }
                    }
                )
            ) {
                Button("好", role: .cancel) {
                    floatingLyrics.dismissError()
                }
            } message: {
                Text(
                    floatingLyrics.errorMessage
                        ?? "系统画中画暂时不可用。"
                )
            }
            .appLaunchExperience()
    }

    @ViewBuilder
    private var playerAwareTabView: some View {
        if player.currentSong != nil {
            tabs
                .overlay(alignment: .bottom) {
                    MiniPlayerView {
                        playerPresentation = .nowPlaying
                    }
                    .background {
                        RoundedRectangle(
                            cornerRadius: Self.miniPlayerCornerRadius,
                            style: .continuous
                        )
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: Self.miniPlayerCornerRadius,
                                style: .continuous
                            )
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                    }
                    .matchedTransitionSource(
                        id: playerTransitionID,
                        in: playerTransitionNamespace
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, Self.tabBarHeight + 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.snappy(duration: 0.3), value: player.currentSong?.id)
        } else {
            tabs
        }
    }

    // iOS 18 没有 tabViewBottomAccessory,迷你播放器需要手动浮在 Tab Bar 之上。
    private static let tabBarHeight: CGFloat = 49
    private static let miniPlayerCornerRadius: CGFloat = 18

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(
                AppTab.home.title,
                systemImage: AppTab.home.systemImage,
                value: AppTab.home
            ) {
                NavigationStack(path: $homePath) {
                    HomeView()
                        .musicDestinations(in: musicNavigationNamespace)
                }
            }

            Tab(
                AppTab.explore.title,
                systemImage: AppTab.explore.systemImage,
                value: AppTab.explore
            ) {
                NavigationStack(path: $explorePath) {
                    ExploreView()
                        .musicDestinations(in: musicNavigationNamespace)
                }
            }

            Tab(
                AppTab.library.title,
                systemImage: AppTab.library.systemImage,
                value: AppTab.library
            ) {
                NavigationStack(path: $libraryPath) {
                    LibraryView()
                        .musicDestinations(in: musicNavigationNamespace)
                }
            }

            Tab(
                AppTab.search.title,
                systemImage: AppTab.search.systemImage,
                value: AppTab.search,
                role: .search
            ) {
                NavigationStack(path: $searchPath) {
                    SearchView()
                        .musicDestinations(in: musicNavigationNamespace)
                }
            }

            Tab(
                AppTab.settings.title,
                systemImage: AppTab.settings.systemImage,
                value: AppTab.settings
            ) {
                NavigationStack(path: $settingsPath) {
                    SettingsView()
                        .musicDestinations(in: musicNavigationNamespace)
                }
            }
        }
        .environment(\.musicNavigationNamespace, musicNavigationNamespace)
    }

    private var initialNowPlayingPage: NowPlayingPage {
        guard settings.rememberNowPlayingPage else { return .artwork }
        return NowPlayingPage(rawValue: settings.rememberedNowPlayingPage) ?? .artwork
    }

    private func openMusicRoute(_ route: MusicRoute) {
        guard playerPresentation == nil else {
            pendingMusicRoute = route
            playerPresentation = nil
            return
        }
        navigate(to: route)
    }

    private func openNeteaseShare(
        _ presentation: NeteaseSharePresentation
    ) {
        presentNeteaseShare(presentation, fromNowPlaying: false)
    }

    private func presentNeteaseShare(
        _ presentation: NeteaseSharePresentation,
        fromNowPlaying: Bool
    ) {
        Task { @MainActor in
            // Menu actions can fire before the system has completed
            // dismissing the menu. Present on the next settled UI turn.
            try? await Task.sleep(for: .milliseconds(140))
            if fromNowPlaying {
                nowPlayingSharePresentation = presentation
            } else {
                neteaseSharePresentation = presentation
            }
        }
    }

    private func finishPendingSongNavigation() {
        guard let route = pendingMusicRoute else { return }
        pendingMusicRoute = nil
        navigate(to: route)
    }

    private func navigate(to route: MusicRoute) {
        switch selectedTab {
        case .home:
            homePath.append(route)
        case .explore:
            explorePath.append(route)
        case .library:
            libraryPath.append(route)
        case .search:
            searchPath.append(route)
        case .settings:
            settingsPath.append(route)
        }
    }
}
