import SwiftUI

struct SongWikiView: View {
    @Environment(NeteaseAPI.self) private var api

    let song: Song

    @State private var wiki: SongWiki?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            switch phase {
            case .loading where wiki == nil:
                ProgressView("ui.song.wiki.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message) where wiki == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }

            default:
                if let wiki, wiki.isEmpty {
                    ContentUnavailableView(
                        "ui.song.wiki.empty",
                        systemImage: "book.closed",
                        description: Text("ui.song.wiki.empty.message")
                    )
                } else if let wiki {
                    SongWikiContent(song: song, wiki: wiki)
                        .refreshable {
                            await load()
                        }
                }
            }
        }
        .navigationTitle("ui.song.wiki.title")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            await load()
        }
        .alert(
            "ui.song.wiki.refresh_failed",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { if !$0 { refreshErrorMessage = nil } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? L10n.string("ui.error.try_again_later"))
        }
    }

    private func load() async {
        phase = .loading
        do {
            let loadedWiki = try await api.songWiki(id: song.id)
            try Task.checkCancellation()
            wiki = loadedWiki
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            if wiki == nil {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                refreshErrorMessage = error.localizedDescription
            }
        }
    }
}
