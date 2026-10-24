import SwiftUI

struct DesktopNowPlayingArtwork: View {
    private static let pausedArtworkScale: CGFloat = 0.74

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    let artworkURL: URL?
    let songName: String?
    let pausedSize: CGFloat
    let isPlaying: Bool
    let shrinksWhenPaused: Bool

    @State private var bounceScale: CGFloat = 1

    private var isExpanded: Bool {
        isPlaying || !shrinksWhenPaused
    }

    private var expansionScale: CGFloat {
        isExpanded ? 1 / Self.pausedArtworkScale : 1
    }

    var body: some View {
        DesktopArtworkView(
            url: artworkURL,
            cornerRadius: 11
        )
        .aspectRatio(1, contentMode: .fit)
        .frame(width: pausedSize, height: pausedSize)
        .scaleEffect(expansionScale * bounceScale)
        .shadow(
            color: .black.opacity(isPlaying ? 0.34 : 0.18),
            radius: isPlaying ? 26 : 14,
            y: isPlaying ? 15 : 8
        )
        .animation(
            accessibilityReduceMotion
                ? nil
                : .smooth(duration: 0.48),
            value: isExpanded
        )
        .animation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.3),
            value: isPlaying
        )
        .accessibilityElement()
        .accessibilityLabel(
            songName.map { L10n.format("ui.song.artwork_accessibility", $0) }
                ?? L10n.string("ui.desktop.player.song_artwork")
        )
        .task(id: isPlaying) {
            await animateBounce(whenPlaying: isPlaying)
        }
    }

    private func animateBounce(whenPlaying: Bool) async {
        bounceScale = 1
        guard whenPlaying, !accessibilityReduceMotion else {
            return
        }

        await Task.yield()
        withAnimation(.easeOut(duration: 0.17)) {
            bounceScale = 1.055
        }

        do {
            try await Task.sleep(for: .milliseconds(170))
        } catch {
            return
        }

        withAnimation(.spring(duration: 0.42, bounce: 0.24)) {
            bounceScale = 1
        }
    }
}
