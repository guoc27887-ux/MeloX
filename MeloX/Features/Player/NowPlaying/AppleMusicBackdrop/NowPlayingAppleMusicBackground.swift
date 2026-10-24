import SwiftUI

struct NowPlayingAppleMusicBackground: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityDimFlashingLights)
    private var accessibilityDimFlashingLights
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase

    let artworkURL: URL?
    let isBehindLyrics: Bool
    let motionIntensity: Double
    let saturation: Double
    let audioResponseEnabled: Bool

    @State private var meshIndex = Int.random(in: 0..<5)
    @State private var pinchMix: Float

    init(
        artworkURL: URL?,
        isBehindLyrics: Bool,
        motionIntensity: Double,
        saturation: Double,
        audioResponseEnabled: Bool
    ) {
        self.artworkURL = artworkURL
        self.isBehindLyrics = isBehindLyrics
        self.motionIntensity = motionIntensity
        self.saturation = saturation
        self.audioResponseEnabled = audioResponseEnabled
        _pinchMix = State(initialValue: isBehindLyrics ? 1 : 0)
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(
                .animation(
                    minimumInterval:
                        isBehindLyrics
                        ? 1.0 / 120.0
                        : 1.0 / 60.0,
                    paused: pausesAnimation
                )
            ) { context in
                let spectrum = effectiveSpectrum

                ZStack {
                    Color(
                        red: 0.18,
                        green: 0.18,
                        blue: 0.18
                    )

                    artwork(in: proxy.size)
                        .layerEffect(
                            AppleMusicBackdropShader.rotation(
                                size: proxy.size,
                                time: animationTime(
                                    at: context.date
                                ),
                                spectrum: spectrum,
                                saturation: saturation,
                                blackScrimAlpha:
                                    colorScheme == .dark
                                    ? 0.5
                                    : 0.35,
                                motionIntensity:
                                    motionIntensity
                            ),
                            maxSampleOffset: proxy.size
                        )
                        .blur(radius: 80, opaque: true)
                        .layerEffect(
                            AppleMusicBackdropShader.pinch(
                                size: proxy.size,
                                time: animationTime(
                                    at: context.date
                                ),
                                pinchMix: pinchMix,
                                meshIndex: meshIndex
                            ),
                            maxSampleOffset: proxy.size
                        )

                    Color.white.opacity(0.1)

                    LinearGradient(
                        colors: [
                            .black.opacity(0),
                            .black,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(0.4)
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .clipped()
            }
        }
        .onChange(of: isBehindLyrics) { _, newValue in
            withAnimation(
                accessibilityReduceMotion
                    ? nil
                    : .timingCurve(
                        0.42,
                        0,
                        0.58,
                        1,
                        duration: 0.4
                    )
            ) {
                pinchMix = newValue ? 1 : 0
            }
        }
    }

    @ViewBuilder
    private func artwork(in size: CGSize) -> some View {
        AsyncImage(
            url: artworkURL,
            transaction: Transaction(
                animation: accessibilityReduceMotion
                    ? nil
                    : .timingCurve(
                        0,
                        0,
                        0.3,
                        1,
                        duration: 0.8
                    )
            )
        ) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Color(
                    red: 0.18,
                    green: 0.18,
                    blue: 0.18
                )
            }
        }
        .id(artworkURL)
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var pausesAnimation: Bool {
        accessibilityReduceMotion
            || isLuminanceReduced
            || scenePhase != .active
            || !player.isPlaying
    }

    private var effectiveSpectrum:
        PlaybackAudioSpectrumSnapshot {
        guard audioResponseEnabled,
              !accessibilityReduceMotion,
              !accessibilityDimFlashingLights,
              !isLuminanceReduced else {
            return .zero
        }
        return player.currentAudioSpectrum
    }

    private func animationTime(
        at date: Date
    ) -> TimeInterval {
        guard !pausesAnimation else {
            return player.estimatedProgress()
        }
        return player.estimatedProgress(at: date)
    }
}
