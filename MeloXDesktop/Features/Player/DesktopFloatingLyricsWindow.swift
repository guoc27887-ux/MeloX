import SwiftUI

struct DesktopFloatingLyricsWindow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isHovered = false
    @State private var playbackProgress: TimeInterval = 0

    private var position: LyricPlaybackPosition {
        LyricPlaybackTimeline.position(
            at: playbackProgress,
            in: model.lyrics.lyrics
        )
    }

    private var currentIndex: Int? {
        guard let id = position.highlightedLyricID else { return nil }
        return model.lyrics.lyrics.firstIndex { $0.id == id }
    }

    private var currentLine: LyricLine? {
        currentIndex.map { model.lyrics.lyrics[$0] }
    }

    private var fontScale: CGFloat {
        CGFloat(model.settings.floatingLyrics.fontScale)
    }

    private var preferences: FloatingLyricsPreferences {
        model.settings.floatingLyrics
    }

    private var textAlignment: TextAlignment {
        switch model.settings.floatingLyrics.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch preferences.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var primaryTextColor: Color {
        preferences.backgroundStyle.usesLightForeground ? .white : .primary
    }

    private var secondaryTextColor: Color {
        preferences.backgroundStyle.usesLightForeground
            ? .white.opacity(0.72)
            : .secondary
    }

    private var textShadowColor: Color {
        switch preferences.textEffect {
        case .none:
            .clear
        case .shadow:
            .black.opacity(0.62)
        case .glow:
            primaryTextColor.opacity(0.48)
        }
    }

    private var textShadowRadius: CGFloat {
        switch preferences.textEffect {
        case .none: 0
        case .shadow: 3
        case .glow: 8
        }
    }

    private var textShadowOffset: CGFloat {
        preferences.textEffect == .shadow ? 1 : 0
    }

    private var showsChrome: Bool {
        isHovered || voiceOverEnabled
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(.rect)
                .accessibilityHidden(true)

            DesktopFloatingLyricsBackground(
                style: preferences.backgroundStyle,
                opacity: preferences.backgroundOpacity,
                blurRadius: CGFloat(preferences.backgroundBlur),
                cornerRadius: CGFloat(preferences.cornerRadius),
                artworkURL: model.player.currentSong?.album?.artworkURL,
                showsChrome: showsChrome
            )

            lyricsContent

            chrome
        }
        .frame(minWidth: 300, minHeight: 72)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        // `estimatedProgress()` only reads the playback timeline clock, so
        // SwiftUI observation never sees `PlayerStore.progress` mutate when
        // this window is the only observer. Mirror the published sample into
        // a local state so the current line advances with the engine clock.
        .onChange(of: model.player.progress, initial: true) { _, _ in
            playbackProgress = model.player.estimatedProgress()
        }
        .onChange(of: model.player.currentSong?.id, initial: true) { _, _ in
            playbackProgress = model.player.estimatedProgress()
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: showsChrome
        )
        .background {
            DesktopFloatingLyricsWindowConfiguration()
                .allowsHitTesting(false)
        }
        .containerBackground(for: .window) {
            Color.clear
        }
    }

    private var lyricsContent: some View {
        VStack(alignment: .leading, spacing: preferences.lineSpacing) {
            Text(currentLine?.text ?? L10n.string("ui.desktop.lyrics.unavailable"))
                .font(
                    .system(
                        size: 26 * fontScale,
                        weight: preferences.fontWeight.swiftUIWeight
                    )
                )
                .foregroundStyle(primaryTextColor.opacity(preferences.textOpacity))
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .shadow(
                    color: textShadowColor,
                    radius: textShadowRadius,
                    y: textShadowOffset
                )
                .contentTransition(.numericText())

            if model.settings.floatingLyrics.showsTranslation,
               let translation = currentLine?.translation,
               !translation.trimmingCharacters(
                   in: .whitespacesAndNewlines
               ).isEmpty {
                Text(translation)
                    .font(
                        .system(
                            size: 14 * fontScale,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(secondaryTextColor.opacity(preferences.textOpacity))
                    .lineLimit(1)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .shadow(
                        color: textShadowColor,
                        radius: textShadowRadius,
                        y: textShadowOffset
                    )
            }

            if model.settings.floatingLyrics.showsNextLine,
               let index = currentIndex,
               model.lyrics.lyrics.indices.contains(index + 1) {
                Text(model.lyrics.lyrics[index + 1].text)
                    .font(
                        .system(
                            size: 17 * fontScale,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(secondaryTextColor.opacity(preferences.textOpacity))
                    .lineLimit(1)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .shadow(
                        color: textShadowColor,
                        radius: textShadowRadius,
                        y: textShadowOffset
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            .snappy(duration: 0.38, extraBounce: 0.1),
            value: position.highlightedLyricID
        )
    }

    private var chrome: some View {
        VStack {
            HStack {
                Text(model.player.currentSong?.name ?? "MeloX")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(
                    systemName: model.player.isPlaying
                        ? "waveform"
                        : "pause.fill"
                )
                .foregroundStyle(.red)

                Button {
                    dismissWindow(id: "floating-lyrics")
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .help(L10n.string("ui.floating_lyrics.close"))
                .accessibilityLabel("ui.floating_lyrics.close")
            }
            Spacer()
        }
        .padding(10)
        .foregroundStyle(primaryTextColor)
        .opacity(showsChrome ? 1 : 0)
        .allowsHitTesting(showsChrome)
        .accessibilityHidden(!showsChrome)
    }
}
