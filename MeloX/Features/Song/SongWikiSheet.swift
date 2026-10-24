import SwiftUI

struct SongWikiSheet: View {
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @Namespace private var navigationNamespace

    var body: some View {
        NavigationStack {
            SongWikiView(song: song)
                .musicDestinations(in: navigationNamespace)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("ui.song.wiki.close")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
