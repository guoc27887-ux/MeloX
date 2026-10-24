import Nuke
import SwiftUI
import UIKit

struct LyricsShareExperienceView: View {
    @State private var store: LyricShareSelectionStore

    init(presentation: LyricSharePresentation) {
        _store = State(
            initialValue: LyricShareSelectionStore(
                presentation: presentation
            )
        )
    }

    var body: some View {
        LyricsSelectionView(store: store)
        .task(id: store.presentation.song.album?.artworkURL) {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        guard store.artwork == nil,
              let url = store.presentation.song.album?.artworkURL else {
            return
        }
        do {
            var request = ImageRequest(url: url)
            request.thumbnail = ImageRequest.ThumbnailOptions(
                size: CGSize(width: 104, height: 104),
                contentMode: .aspectFill
            )
            let image = try await ImagePipeline.shared.image(for: request)
            guard !Task.isCancelled else { return }
            store.artwork = image
        } catch {
            return
        }
    }
}
