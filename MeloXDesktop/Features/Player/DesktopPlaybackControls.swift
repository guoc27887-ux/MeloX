import SwiftUI

struct DesktopPlaybackControls: View {
    @Environment(DesktopAppModel.self) private var model
    var prominent = false
    var tint: Color = .primary
    var prominentWidth: CGFloat = 320
    var prominentEdgeInset: CGFloat = 0
    var prominentScale: CGFloat = 1
    var secondaryTintOpacity = 0.58

    private var controlScale: CGFloat {
        prominent ? max(prominentScale, 1) : 1
    }

    var body: some View {
        Group {
            if prominent {
                prominentControls
            } else {
                compactControls
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }

    private var prominentControls: some View {
        HStack(spacing: 0) {
            shuffleButton
                .frame(width: 28 * controlScale)
            Spacer(minLength: 0)
            previousButton
                .frame(width: 36 * controlScale)
            Spacer(minLength: 0)
            playButton
                .frame(width: 48 * controlScale)
            Spacer(minLength: 0)
            nextButton
                .frame(width: 36 * controlScale)
            Spacer(minLength: 0)
            repeatButton
                .frame(width: 28 * controlScale)
        }
        .padding(.horizontal, prominentEdgeInset)
        .frame(width: prominentWidth)
    }

    private var compactControls: some View {
        HStack(spacing: 0) {
            shuffleButton.frame(width: 28, height: 28)
            previousButton.frame(width: 28, height: 28)
            playButton.frame(width: 36, height: 36)
            nextButton.frame(width: 28, height: 28)
            repeatButton.frame(width: 28, height: 28)
        }
        .frame(width: 148, height: 36)
    }

    private var shuffleButton: some View {
        Button {
            model.player.toggleShuffle()
        } label: {
            Image(systemName: "shuffle")
                .font(
                    .system(
                        size: (prominent ? 16 : 11) * controlScale,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    model.player.isShuffled
                        ? .red
                        : tint.opacity(secondaryTintOpacity)
                )
        }
        .help(
            model.player.isShuffled
                ? L10n.string("ui.player.shuffle_off")
                : L10n.string("ui.player.shuffle_on")
        )
    }

    private var previousButton: some View {
        Button {
            Task { await model.player.previous() }
        } label: {
            Image(systemName: "backward.fill")
                .font(
                    .system(
                        size: (prominent ? 24 : 13) * controlScale,
                        weight: .semibold
                    )
                )
        }
        .help(L10n.string("ui.player.previous"))
    }

    private var playButton: some View {
        Button {
            model.player.togglePlayback()
        } label: {
            Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                .font(
                    .system(
                        size: (prominent ? 30 : 19) * controlScale,
                        weight: .semibold
                    )
                )
                .contentTransition(
                    .symbolEffect(
                        .replace,
                        options: .speed(DesktopPlayerMotion.playbackSymbolSpeed)
                    )
                )
        }
        .keyboardShortcut(
            DesktopPlaybackKeyboardShortcuts.togglePlayback
        )
        .help(
            model.player.isPlaying
                ? L10n.string("ui.desktop.player.pause_space")
                : L10n.string("ui.desktop.player.play_space")
        )
    }

    private var nextButton: some View {
        Button {
            Task { await model.player.next() }
        } label: {
            Image(systemName: "forward.fill")
                .font(
                    .system(
                        size: (prominent ? 24 : 13) * controlScale,
                        weight: .semibold
                    )
                )
        }
        .disabled(!model.player.canPlayNext)
        .help(L10n.string("ui.player.next"))
    }

    private var repeatButton: some View {
        Button {
            model.player.cycleRepeatMode()
        } label: {
            Image(systemName: model.player.repeatMode.systemImage)
                .font(
                    .system(
                        size: (prominent ? 16 : 11) * controlScale,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    model.player.repeatMode == .off
                        ? tint.opacity(secondaryTintOpacity)
                        : .red
                )
        }
        .help(model.player.repeatMode.accessibilityTitle)
    }
}

struct DesktopPlaybackProgress: View {
    @Environment(DesktopAppModel.self) private var model
    var tint: Color = .primary
    var showsTimes = true

    var body: some View {
        VStack(spacing: 0) {
            Slider(
                value: Binding(
                    get: { min(model.player.progress, max(model.player.duration, 0)) },
                    set: { model.player.seek(to: $0) }
                ),
                in: 0...max(model.player.duration, 1)
            )
            .tint(tint)
            .controlSize(.mini)

            if showsTimes {
                HStack {
                    Text(format(model.player.progress))
                    Spacer()
                    Text("−\(format(max(model.player.duration - model.player.progress, 0)))")
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(tint.opacity(0.60))
                .padding(.top, 10)
            }
        }
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let seconds = max(Int(time), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct DesktopVolumeControl: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = .primary
    @Binding var isExpanded: Bool
    @State private var volumeAnimationTrigger = 0
    @State private var isVolumeTrackHovered = false

    var body: some View {
        if model.playbackVolume.isControlVisible {
            surfacedControl
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(.capsule)
                .onHover { hovering in
                    guard !hovering, isExpanded else { return }
                    setExpanded(false)
                }
                .animation(
                    reduceMotion
                        ? nil
                        : DesktopPlayerMotion.volume(expanded: isExpanded),
                    value: isExpanded
                )
        }
    }

    @ViewBuilder
    private var surfacedControl: some View {
        if #available(macOS 26.0, *) {
            controlContent
                .glassEffect(
                    isExpanded ? .regular.interactive() : .identity,
                    in: .capsule
                )
        } else {
            controlContent
                .background {
                    if isExpanded {
                        Capsule()
                            .fill(tint.opacity(0.08))
                    }
                }
        }
    }

    private var controlContent: some View {
        HStack(spacing: isExpanded ? 14 : 0) {
            if isExpanded {
                volumeTrack
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                handleVolumeButton()
            } label: {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(
                        .bounce,
                        options: reduceMotion ? .nonRepeating : .default,
                        value: volumeAnimationTrigger
                    )
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(
                isExpanded
                    ? L10n.string("ui.desktop.player.toggle_mute")
                    : L10n.string("ui.desktop.player.show_volume")
            )
        }
        .padding(.leading, isExpanded ? 10 : 9)
        .padding(.trailing, 9)
        .frame(height: 36)
        .contentShape(.capsule)
    }

    @ViewBuilder
    private var volumeTrack: some View {
        if #available(macOS 26.0, *) {
            volumeSlider
                .sliderThumbVisibility(
                    isVolumeTrackHovered ? .visible : .hidden
                )
                .onHover { isVolumeTrackHovered = $0 }
        } else {
            volumeSlider
        }
    }

    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { model.playbackVolume.volume },
                set: { setExpandedVolume($0) }
            ),
            in: 0...1
        )
        .tint(tint)
        .controlSize(.small)
        .frame(width: 64, height: 18)
        .accessibilityLabel("ui.player.volume")
        .help(L10n.string("ui.player.volume"))
    }

    private func setExpandedVolume(_ value: Double) {
        model.playbackVolume.setVolume(value)
    }

    private func handleVolumeButton() {
        guard isExpanded else {
            setExpanded(true)
            return
        }

        model.playbackVolume.toggleMuted()
        volumeAnimationTrigger += 1
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(
            reduceMotion
                ? nil
                : DesktopPlayerMotion.volume(expanded: expanded)
        ) {
            isExpanded = expanded
        }
    }

    private var volumeSymbol: String {
        switch model.playbackVolume.volume {
        case ...0.001: "speaker.slash.fill"
        case ..<0.35: "speaker.wave.1.fill"
        case ..<0.7: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
