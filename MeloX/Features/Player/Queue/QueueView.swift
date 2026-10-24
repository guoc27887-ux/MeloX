import SwiftUI

struct QueueView: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        List(Array(player.queue.enumerated()), id: \.element.id) { index, song in
            Button {
                Task { await player.playFromQueue(at: index) }
            } label: {
                HStack {
                    TrackRowView(song: song, showsArtwork: true)
                    if index == player.currentIndex {
                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("ui.player.current_song")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .navigationTitle("ui.player.up_next")
        .overlay {
            if player.queue.isEmpty {
                ContentUnavailableView("ui.player.queue_empty", systemImage: "list.bullet")
            }
        }
    }
}
