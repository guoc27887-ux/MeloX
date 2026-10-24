import CoreGraphics
import SwiftUI

struct FloatingLyricsPresentation: Equatable {
    let songID: Int?
    let title: String
    let artist: String
    let currentLine: LyricLine?
    let upcomingLines: [LyricLine]
    let fallbackText: String
    let playbackTime: TimeInterval
    let isPlaying: Bool
    let usesPseudoTiming: Bool
    let showsTranslation: Bool
    let fontScale: Double
}

struct FloatingLyricsContentView: View {
    let presentation: FloatingLyricsPresentation
    let artworkImage: CGImage?

    var body: some View {
        ZStack {
            ambientBackground

            HStack(spacing: 32) {
                artworkPanel
                    .frame(width: 224)

                lyricsPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .foregroundStyle(.white)
        .clipped()
    }

    @ViewBuilder
    private var ambientBackground: some View {
        if let artworkImage {
            artworkImageView(artworkImage)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.18)
                .blur(radius: 58)
                .saturation(1.18)
                .opacity(0.42)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.03, blue: 0.06),
                    .black,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        Color.black.opacity(artworkImage == nil ? 0.28 : 0.62)

        LinearGradient(
            colors: [
                .black.opacity(0.06),
                .black.opacity(0.52),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var artworkPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            albumArtwork

            Text(presentation.title)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(presentation.artist)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var albumArtwork: some View {
        ZStack {
            if let artworkImage {
                artworkImageView(artworkImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        .white.opacity(0.16),
                        .white.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text("♪")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .frame(width: 214, height: 214)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.46), radius: 20, y: 10)
    }

    private var lyricsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            currentLyric

            VStack(alignment: .leading, spacing: 12) {
                ForEach(
                    Array(presentation.upcomingLines.prefix(2).enumerated()),
                    id: \.element.id
                ) { index, line in
                    Text(verbatim: line.text)
                        .font(
                            .system(
                                size: (index == 0 ? 25 : 22)
                                    * presentation.fontScale,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(index == 0 ? 0.30 : 0.14)
                        )
                        .blur(radius: index == 0 ? 0.45 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var currentLyric: some View {
        if let line = presentation.currentLine {
            SynchronizedLyricText(
                line: line,
                isPlaybackLine: true,
                usesPseudoTiming: presentation.usesPseudoTiming,
                fontSize: 46 * presentation.fontScale,
                fontScale: presentation.fontScale,
                primaryColor: .white,
                showsTranslation: presentation.showsTranslation,
                showsRomanization: false,
                layoutWidth: 648,
                playbackScaleRange: 1...1.035,
                playbackScaleStartDelay: 0.08
            )
            .scaleEffect(
                0.97 + 0.03 * focusEntryProgress,
                anchor: .leading
            )
            .offset(y: 12 * (1 - focusEntryProgress))
            .opacity(0.55 + 0.45 * focusEntryProgress)
        } else {
            Text(presentation.fallbackText)
                .font(
                    .system(
                        size: 46 * presentation.fontScale,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.62)
        }
    }

    private var focusEntryProgress: CGFloat {
        guard let line = presentation.currentLine else { return 1 }
        let rawProgress = min(
            max((presentation.playbackTime - line.time) / 0.36, 0),
            1
        )
        let easedProgress = rawProgress
            * rawProgress
            * (3 - 2 * rawProgress)
        return CGFloat(easedProgress)
    }

    private func artworkImageView(_ image: CGImage) -> Image {
        Image(
            decorative: image,
            scale: 1,
            orientation: .up
        )
    }
}

#Preview("Floating Lyrics") {
    FloatingLyricsContentView(
        presentation: FloatingLyricsPresentation(
            songID: 1,
            title: L10n.string("ui.preview.now_playing_song"),
            artist: L10n.string("ui.common.artist"),
            currentLine: nil,
            upcomingLines: [
                LyricLine(
                    time: 18,
                    text: L10n.string("ui.preview.next_lyric")
                ),
                LyricLine(
                    time: 24,
                    text: L10n.string("ui.preview.distant_lyrics")
                ),
            ],
            fallbackText: L10n.string("ui.preview.floating_lyrics_fallback"),
            playbackTime: 12.5,
            isPlaying: true,
            usesPseudoTiming: false,
            showsTranslation: true,
            fontScale: 1
        ),
        artworkImage: nil
    )
    .frame(width: 480, height: 160)
}
