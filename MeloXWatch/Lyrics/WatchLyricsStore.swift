import Combine
import Foundation

@MainActor
final class WatchLyricsStore: ObservableObject {
    @Published private(set) var songID: Int?
    @Published private(set) var lyrics: [WatchLyricLine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: WatchNeteaseAPI
    private var generation = 0

    init(api: WatchNeteaseAPI) {
        self.api = api
    }

    func load(songID: Int?) async {
        guard self.songID != songID || lyrics.isEmpty else { return }
        generation += 1
        let currentGeneration = generation
        self.songID = songID
        lyrics = []
        errorMessage = nil
        isLoading = songID != nil

        guard let songID else {
            isLoading = false
            return
        }

        do {
            let loaded = try await api.lyrics(id: songID)
            guard currentGeneration == generation else { return }
            lyrics = loaded
            errorMessage = loaded.isEmpty
                ? L10n.string("ui.watch.lyrics.no_synced_lyrics")
                : nil
            isLoading = false
        } catch is CancellationError {
            guard currentGeneration == generation else { return }
            isLoading = false
        } catch {
            guard currentGeneration == generation else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
