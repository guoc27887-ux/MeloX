import SwiftUI

struct DesktopFloatingLyricsBackground: View {
    let style: FloatingLyricsBackgroundStyle
    let opacity: Double
    let blurRadius: CGFloat
    let cornerRadius: CGFloat
    let artworkURL: URL?
    let showsChrome: Bool

    var body: some View {
        GeometryReader { proxy in
            backgroundContent(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(backgroundShape)
                .overlay {
                    backgroundShape
                        .stroke(.white.opacity(showsChrome ? 0.18 : 0), lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func backgroundContent(in size: CGSize) -> some View {
        switch style {
        case .transparent:
            backgroundShape
                .fill(.regularMaterial)
                .opacity(showsChrome ? 0.72 : 0)

        case .material:
            backgroundShape
                .fill(.regularMaterial)
                .opacity(opacity)

        case .light:
            Color.white.opacity(opacity)

        case .dark:
            Color.black.opacity(opacity)

        case .blurredArtwork:
            blurredArtwork(in: size)
        }
    }

    private func blurredArtwork(in size: CGSize) -> some View {
        AsyncImage(url: artworkURL) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.18)
                    .blur(radius: blurRadius)
                    .overlay(Color.black.opacity(0.28))
                    .opacity(opacity)
            } else {
                Color.black.opacity(opacity)
            }
        }
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }
}
