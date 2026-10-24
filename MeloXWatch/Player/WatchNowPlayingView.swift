import SwiftUI

struct WatchNowPlayingView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    @AppStorage(WatchPreferenceKey.shrinksPausedArtwork)
    private var shrinksPausedArtwork = false
    @AppStorage(WatchPreferenceKey.showsArtist)
    private var showsArtist = true

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(
                size: proxy.size,
                showsArtist: showsArtist
            )

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: metrics.artworkTopInset)

                artwork(size: metrics.artworkSize)

                Color.clear
                    .frame(
                        height: metrics.artworkToMetadataSpacing
                    )

                titleBlock(height: metrics.titleHeight)

                Spacer(
                    minLength: metrics.metadataToControlsSpacing
                )

                transportControls(metrics: metrics)

                Color.clear
                    .frame(height: metrics.bottomControlInset)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .bottom
            )
        }
        .background(.clear)
        .ignoresSafeArea(.container, edges: .all)
        .scrollDisabled(true)
        .overlay(alignment: .topTrailing) {
            if let quality = coordinator.effectiveStreamingQuality {
                Label(quality.title, systemImage: "waveform")
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: .capsule)
                    .padding(.top, 5)
                    .padding(.trailing, 6)
                    .accessibilityLabel(
                        L10n.string("ui.watch.now_playing.effective_quality")
                    )
                    .accessibilityValue(quality.title)
            }
        }
    }

    private func artwork(size: CGFloat) -> some View {
        AsyncImage(url: coordinator.song?.album?.artworkURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color(white: 0.27))
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(Color(white: 0.66))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: max(size * 0.07, 7)))
        .scaleEffect(
            shrinksPausedArtwork && !coordinator.isPlaying ? 0.94 : 1
        )
        .animation(
            reducesMotion ? nil : .spring(duration: 0.5, bounce: 0.18),
            value: coordinator.isPlaying
        )
        .accessibilityHidden(true)
    }

    private func titleBlock(height: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(
                coordinator.song?.name
                    ?? L10n.string("ui.player.not_playing")
            )
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if showsArtist, let artist = coordinator.song?.artistText {
                Text(artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(height: height, alignment: .center)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func transportControls(metrics: Metrics) -> some View {
        if #available(watchOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                transportButtons(metrics: metrics)
            }
        } else {
            transportButtons(metrics: metrics)
        }
    }

    private func transportButtons(metrics: Metrics) -> some View {
        HStack {
            Button {
                Task { await coordinator.previous() }
            } label: {
                WatchCircularControlLabel(
                    systemImage: "backward.fill",
                    size: metrics.sideControlSize,
                    iconScale: 0.42
                )
            }
            .buttonStyle(.plain)
            .disabled(coordinator.song == nil)
            .accessibilityLabel("ui.player.previous")

            Spacer(minLength: 4)

            Button {
                coordinator.togglePlayback()
            } label: {
                primaryPlaybackControl(
                    size: metrics.centerControlSize
                )
            }
            .buttonStyle(.plain)
            .disabled(coordinator.song == nil)
            .accessibilityLabel(
                L10n.string(
                    coordinator.isPlaying
                        ? "ui.action.pause"
                        : "ui.action.play"
                )
            )

            Spacer(minLength: 4)

            Button {
                Task { await coordinator.next() }
            } label: {
                WatchCircularControlLabel(
                    systemImage: "forward.fill",
                    size: metrics.sideControlSize,
                    iconScale: 0.42
                )
            }
            .buttonStyle(.plain)
            .disabled(coordinator.queue.count < 2)
            .accessibilityLabel("ui.player.next")
        }
        .frame(height: metrics.centerControlSize)
        .padding(
            .horizontal,
            metrics.transportHorizontalInset
        )
    }

    @ViewBuilder
    private func primaryPlaybackControl(size: CGFloat) -> some View {
        if #available(watchOS 26.0, *) {
            playbackSymbol(size: size)
                .frame(width: size, height: size)
                .glassEffect(
                    .regular
                        .tint(.white.opacity(0.08))
                        .interactive(),
                    in: .circle
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                Circle()
                    .stroke(
                        Color.white.opacity(0.18),
                        lineWidth: 2
                    )
                playbackSymbol(size: size)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func playbackSymbol(size: CGFloat) -> some View {
        if coordinator.isLoading {
            ProgressView()
        } else {
            Image(
                systemName: coordinator.isPlaying
                    ? "pause.fill"
                    : "play.fill"
            )
            .font(
                .system(
                    size: size * 0.42,
                    weight: .semibold
                )
            )
            .offset(
                x: coordinator.isPlaying ? 0 : size * 0.025
            )
        }
    }
}

private extension WatchNowPlayingView {
    struct Metrics {
        let horizontalPadding: CGFloat
        let artworkSize: CGFloat
        let titleHeight: CGFloat
        let sideControlSize: CGFloat
        let centerControlSize: CGFloat
        let transportHorizontalInset: CGFloat
        let artworkTopInset: CGFloat
        let artworkToMetadataSpacing: CGFloat
        let metadataToControlsSpacing: CGFloat
        let bottomControlInset: CGFloat

        init(size: CGSize, showsArtist: Bool) {
            let veryCompact =
                size.height < 220 || size.width < 185
            let compact =
                size.height < 270 || size.width < 220

            horizontalPadding = veryCompact ? 6 : compact ? 8 : 10
            titleHeight = showsArtist
                ? (veryCompact ? 34 : compact ? 37 : 40)
                : (veryCompact ? 21 : compact ? 23 : 25)
            sideControlSize = veryCompact ? 30 : compact ? 36 : 40
            centerControlSize = veryCompact ? 40 : compact ? 46 : 50
            transportHorizontalInset =
                veryCompact ? 5 : compact ? 7 : 8
            artworkTopInset = veryCompact ? 30 : compact ? 44 : 48
            artworkToMetadataSpacing =
                veryCompact ? 6 : compact ? 10 : 12
            metadataToControlsSpacing =
                veryCompact ? 4 : compact ? 6 : 8
            bottomControlInset = veryCompact ? 6 : compact ? 8 : 10

            let reservedHeight =
                artworkTopInset
                + titleHeight
                + centerControlSize
                + artworkToMetadataSpacing
                + metadataToControlsSpacing
                + bottomControlInset
            let availableArtworkHeight = max(
                size.height - reservedHeight,
                veryCompact ? 54 : 72
            )
            artworkSize = min(
                size.width
                    * (
                        veryCompact
                            ? 0.43
                            : compact ? 0.46 : 0.48
                    ),
                availableArtworkHeight,
                veryCompact ? 72 : compact ? 96 : 108
            )
        }
    }
}
