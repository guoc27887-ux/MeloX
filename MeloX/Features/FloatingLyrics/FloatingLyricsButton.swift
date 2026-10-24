import SwiftUI

struct FloatingLyricsButton: View {
    @Environment(PlayerStore.self) private var player
    @Environment(FloatingLyricsController.self) private var floatingLyrics

    var body: some View {
        Button {
            floatingLyrics.toggle()
        } label: {
            Image(
                systemName: floatingLyrics.isActive
                    ? "pip.exit"
                    : "pip.enter"
            )
            .font(.title3)
            .frame(width: 44, height: 44)
            .background(
                .white.opacity(floatingLyrics.isActive ? 0.2 : 0),
                in: .circle
            )
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(
            player.currentSong == nil
                || (!floatingLyrics.isActive && !floatingLyrics.isPossible)
        )
        .accessibilityLabel(
            floatingLyrics.isActive
                ? L10n.string("ui.floating_lyrics.close")
                : L10n.string("ui.floating_lyrics.open")
        )
        .accessibilityHint("ui.floating_lyrics.picture_in_picture_hint")
    }
}
