import SwiftUI

struct DesktopArtistDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let artistID: Int

    @State private var artist: Artist?
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var isFollowed = false
    @State private var isChangingFollowState = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var operationError: String?

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        Group {
            if let artist {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        artistHero(artist)

                        HStack(alignment: .top, spacing: 36) {
                            VStack(alignment: .leading, spacing: 12) {
                                DesktopSectionHeader(title: L10n.string("ui.desktop.artist.latest_releases"))
                                LazyVGrid(columns: columns, spacing: 22) {
                                    ForEach(Array(albums.prefix(8))) { album in
                                        DesktopMediaCard(
                                            title: album.name,
                                            subtitle: album.artistText,
                                            artworkURL: album.artworkURL,
                                            action: { model.ui.navigate(to: .album(album.id)) },
                                            playAction: { play(album) }
                                        )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                            VStack(alignment: .leading, spacing: 12) {
                                DesktopSectionHeader(title: L10n.string("ui.artist.popular_songs"))
                                DesktopCollectionTrackList(
                                    songs: Array(songs.prefix(12)),
                                    sourceID: artist.id
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .padding(.horizontal, 34)
                        .padding(.bottom, 30)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.artist.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load() }
                }
            }
        }
        .navigationTitle(artist?.name ?? L10n.string("ui.common.artist"))
        .task(id: artistID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
        .alert(
            L10n.string("ui.desktop.artist.follow_failed"),
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("ui.common.ok") { operationError = nil }
        } message: {
            Text(operationError ?? L10n.string("ui.error.netease_operation_incomplete"))
        }
    }

    private func artistHero(_ artist: Artist) -> some View {
        ZStack(alignment: .bottomLeading) {
            DesktopArtworkView(
                url: artist.artworkURL,
                cornerRadius: 0
            )
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .scaleEffect(1.38)
            .blur(radius: 48)
            .opacity(0.58)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.62),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    DesktopCircularArtworkView(url: artist.artworkURL)
                        .frame(width: 190, height: 190)
                        .shadow(radius: 18, y: 8)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await model.player.playAll(songs, sourceID: artist.id) }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.red, in: .circle)
                    }
                    .buttonStyle(.plain)

                    Button(
                        isFollowed
                            ? L10n.string("ui.desktop.artist.following")
                            : L10n.string("ui.desktop.artist.follow"),
                        systemImage: isFollowed ? "checkmark" : "plus"
                    ) {
                        toggleFollowState(artist)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(isChangingFollowState)

                    if let url = URL(
                        string: "https://music.163.com/#/artist?id=\(artist.id)"
                    ) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .help(L10n.string("ui.common.share"))
                    }

                    Text(artist.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.leading, 4)
                }
            }
            .padding(34)
        }
        .frame(height: 380)
        .clipped()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await model.api.artist(id: artistID)
            artist = detail.0
            songs = detail.1
            albums = detail.2
            isFollowed = detail.0.isFollowed
                || model.library.contains(artist: detail.0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleFollowState(_ artist: Artist) {
        guard !isChangingFollowState else { return }
        let requested = !isFollowed
        let previous = isFollowed
        isChangingFollowState = true
        isFollowed = requested

        Task {
            defer { isChangingFollowState = false }
            do {
                try await model.library.setArtistFollowed(
                    artist,
                    isFollowed: requested
                )
            } catch {
                isFollowed = previous
                operationError = error.localizedDescription
            }
        }
    }

    private func play(_ album: Album) {
        Task {
            guard let detail = try? await model.api.album(id: album.id) else { return }
            await model.player.playAll(detail.1, sourceID: album.id)
        }
    }
}
