import SwiftUI

struct NowPlayingBackground: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    let artworkURL: URL?
    let beatTimeline: PlaybackBeatTimeline?
    let isBehindLyrics: Bool

    @State private var flowingLightPalette:
        ArtworkFlowingLightPalette

    init(
        artworkURL: URL?,
        beatTimeline: PlaybackBeatTimeline?,
        isBehindLyrics: Bool
    ) {
        self.artworkURL = artworkURL
        self.beatTimeline = beatTimeline
        self.isBehindLyrics = isBehindLyrics
        _flowingLightPalette = State(
            initialValue:
                ArtworkAccentColorProvider
                    .cachedDetailAssets(
                        for: artworkURL
                    )?
                    .flowingLightPalette
                    ?? .fallback
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                backgroundContent(in: proxy.size)
                    .transition(.opacity)

                Color.black.opacity(backgroundVeilOpacity)

                LinearGradient(
                    colors: legibilityGradientColors,
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
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .animation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.55),
            value: settings.playerBackgroundStyle
        )
        .task(id: paletteTaskID) {
            await loadFlowingLightPalette()
        }
    }

    @ViewBuilder
    private func backgroundContent(
        in size: CGSize
    ) -> some View {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            NowPlayingAppleMusicBackground(
                artworkURL: artworkURL,
                isBehindLyrics: isBehindLyrics,
                motionIntensity:
                    settings.playerBackgroundMotionIntensity,
                saturation:
                    settings.playerBackgroundSaturation,
                audioResponseEnabled:
                    settings
                        .playerBackgroundAudioResponseEnabled
            )
            .frame(
                width: size.width,
                height: size.height
            )

        case .flowingLight:
            NowPlayingFlowingLightBackground(
                palette: flowingLightPalette,
                beatTimeline: beatTimeline,
                motionIntensity:
                    settings.playerBackgroundMotionIntensity,
                saturation:
                    settings.playerBackgroundSaturation,
                beatEffectsEnabled:
                    settings
                        .playerBackgroundBeatEffectsEnabled
            )
            .frame(
                width: size.width,
                height: size.height
            )

        case .blurredArtwork:
            blurredArtworkBackground(in: size)
        }
    }

    @ViewBuilder
    private func blurredArtworkBackground(
        in size: CGSize
    ) -> some View {
        AsyncImage(url: artworkURL) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: size.width,
                        height: size.height
                    )
                    .clipped()
                    .scaleEffect(1.35)
                    .blur(
                        radius:
                            CGFloat(
                                settings
                                    .playerBackgroundBlur
                            )
                    )
                    .saturation(
                        settings.playerBackgroundSaturation
                    )
            }
        }
    }

    private var backgroundVeilOpacity: Double {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            0
        case .flowingLight:
            0.02
        case .blurredArtwork:
            0.10
        }
    }

    private var legibilityGradientColors: [Color] {
        switch settings.playerBackgroundStyle {
        case .appleMusicBackdrop:
            [
                .clear,
                .clear,
            ]
        case .flowingLight:
            [
                .black.opacity(0.015),
                .black.opacity(0.05),
                .black.opacity(0.36),
            ]
        case .blurredArtwork:
            [
                .black.opacity(0.04),
                .black.opacity(0.12),
                .black.opacity(0.48),
            ]
        }
    }

    private var paletteTaskID:
        NowPlayingBackgroundPaletteTaskID {
        NowPlayingBackgroundPaletteTaskID(
            artworkURL: artworkURL,
            usesFlowingLight:
                settings.playerBackgroundStyle
                    == .flowingLight
        )
    }

    private func loadFlowingLightPalette() async {
        guard settings.playerBackgroundStyle
            == .flowingLight else {
            return
        }
        let assets =
            await ArtworkAccentColorProvider
                .shared
                .detailAssets(
                    for: artworkURL,
                    fallbackPrefersDarkAppearance: true
                )
        guard !Task.isCancelled,
              assets.flowingLightPalette
                != flowingLightPalette else {
            return
        }
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.8)
        ) {
            flowingLightPalette =
                assets.flowingLightPalette
        }
    }
}

private struct NowPlayingBackgroundPaletteTaskID:
    Equatable {
    let artworkURL: URL?
    let usesFlowingLight: Bool
}
