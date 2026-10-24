import SwiftUI

struct DesktopAlbumDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let albumID: Int

    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var isSubscribed = false
    @State private var isChangingSubscription = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var operationError: String?

    var body: some View {
        Group {
            if let album {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 34) {
                        DesktopCollectionHeader(
                            artworkURL: album.artworkURL,
                            kind: album.type ?? L10n.string("ui.common.album"),
                            title: album.name,
                            subtitle: album.artistText,
                            metadata: metadata(album),
                            description: album.albumDescription,
                            songs: songs,
                            sourceID: album.id,
                            isFavorite: isSubscribed,
                            favoriteAction: toggleSubscription,
                            shareURL: URL(
                                string: "https://music.163.com/#/album?id=\(album.id)"
                            )
                        )

                        Divider()
                        DesktopCollectionTrackList(
                            songs: songs,
                            sourceID: album.id,
                            showsAlbumColumn: false,
                            usesTrackNumbers: true,
                            groupsByDisc: true
                        )
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: L10n.string("ui.album.loading"))
            } else {
                DesktopDetailErrorView(message: errorMessage ?? L10n.string("ui.error.unknown")) {
                    Task { await load() }
                }
            }
        }
        .navigationTitle(album?.name ?? L10n.string("ui.common.album"))
        .task(id: albumID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
        .alert(
            L10n.string("ui.error.favorite_failed"),
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

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await model.api.album(id: albumID)
            album = detail.0
            songs = detail.1
            let dynamicSubscription = (
                try? await model.api.albumSubscriptionStatus(id: albumID)
            ) ?? false
            isSubscribed = model.library.contains(album: detail.0)
                || detail.0.isSubscribed
                || dynamicSubscription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleSubscription() {
        guard !isChangingSubscription, let album else { return }
        Task {
            let requested = !isSubscribed
            let previous = isSubscribed
            isChangingSubscription = true
            isSubscribed = requested
            defer { isChangingSubscription = false }
            do {
                try await model.library.setAlbumSubscribed(
                    album,
                    isSubscribed: requested
                )
            } catch {
                isSubscribed = previous
                operationError = error.localizedDescription
            }
        }
    }

    private func metadata(_ album: Album) -> String {
        var values: [String] = []
        if let publishTime = album.publishTime {
            values.append(
                Date(timeIntervalSince1970: publishTime / 1_000).formatted(
                    .dateTime.year().locale(L10n.locale)
                )
            )
        }
        if let size = album.size { values.append(L10n.format("ui.common.song_count", size)) }
        values.append(model.settings.quality.title)
        return L10n.joined(
            values,
            separatorKey: "ui.common.metadata_separator"
        )
    }
}
