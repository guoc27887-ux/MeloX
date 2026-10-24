import SwiftUI

private enum WatchPlayerPage: Hashable {
    case queue
    case nowPlaying
    case lyrics
}

struct WatchRootView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @State private var selectedPage = WatchPlayerPage.nowPlaying

    let api: WatchNeteaseAPI

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                artworkBackedPage {
                    WatchQueueView()
                }
                    .tag(WatchPlayerPage.queue)

                artworkBackedPage {
                    WatchNowPlayingView()
                }
                    .tag(WatchPlayerPage.nowPlaying)

                WatchLyricsPage(
                    isActive: selectedPage == .lyrics
                )
                    .tag(WatchPlayerPage.lyrics)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        WatchMenuView(api: api)
                    } label: {
                        WatchCircularControlLabel(
                            systemImage: "list.bullet",
                            size: topControlSize,
                            iconScale: 0.46
                        )
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .accessibilityLabel("ui.watch.menu.open")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func artworkBackedPage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            WatchNowPlayingBackground(
                artworkURL: coordinator.song?.album?.artworkURL
            )
            .ignoresSafeArea()

            content()
        }
    }

    private var topControlSize: CGFloat {
        34
    }
}
