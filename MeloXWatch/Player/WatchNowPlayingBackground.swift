import SwiftUI

struct WatchNowPlayingBackground: View {
    @AppStorage(WatchPreferenceKey.playerBackgroundBlur)
    private var blurRadius = 18.0
    @AppStorage(WatchPreferenceKey.playerBackgroundDim)
    private var dimAmount = 0.62
    @AppStorage(WatchPreferenceKey.playerBackgroundSaturation)
    private var saturation = 1.15

    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let artworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.black
                        }
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .saturation(saturation)
                    .scaleEffect(1.35)
                    .blur(radius: blurRadius, opaque: true)
                    .transition(.opacity)
                }

                Color.black.opacity(dimAmount)

                LinearGradient(
                    colors: [
                        .black.opacity(0.12),
                        .clear,
                        .black.opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
