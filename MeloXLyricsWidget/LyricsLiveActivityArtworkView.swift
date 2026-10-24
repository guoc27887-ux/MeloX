import ImageIO
import SwiftUI

struct LyricsLiveActivityArtworkView: View {
    let state: LyricsLiveActivityAttributes.ContentState
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if state.presentation.showsArtwork {
                artwork
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = decodedImage {
            image.resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var decodedImage: Image? {
        guard let data = state.artworkData,
              let source = CGImageSourceCreateWithData(
                data as CFData,
                nil
              ),
              let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                [
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary
              )
        else {
            return nil
        }
        return Image(
            decorative: image,
            scale: CGFloat(
                LyricsLiveActivityArtworkPolicy
                    .imageScale
            ),
            orientation: .up
        )
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.12)
            Image(systemName: "music.note")
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
