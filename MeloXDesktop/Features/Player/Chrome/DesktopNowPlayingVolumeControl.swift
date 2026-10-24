import SwiftUI

struct DesktopNowPlayingVolumeControl: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.playbackVolume.isControlVisible {
            content.modifier(DesktopNowPlayingGlassCapsule())
        }
    }

    private var content: some View {
        HStack(spacing: 1) {
            indicatedVolumeSlider

            Button {
                model.playbackVolume.toggleMuted(minimumRestoreVolume: 0.2)
            } label: {
                Label(
                    currentVolume > 0.001
                        ? L10n.string("ui.desktop.player.mute")
                        : L10n.string("ui.desktop.player.unmute"),
                    systemImage: volumeSymbol
                )
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                currentVolume > 0.001
                    ? L10n.string("ui.desktop.player.mute")
                    : L10n.string("ui.desktop.player.unmute")
            )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 36)
    }

    @ViewBuilder
    private var indicatedVolumeSlider: some View {
        if #available(macOS 26.0, *) {
            volumeSlider
                .sliderThumbVisibility(.visible)
        } else {
            volumeSlider
        }
    }

    private var volumeSlider: some View {
        Slider(
            value: volumeBinding,
            in: 0...1
        )
        .tint(.white)
        .controlSize(.mini)
        .frame(width: 130, height: 22)
        .contentShape(.rect)
        .accessibilityLabel("ui.player.volume")
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { currentVolume },
            set: { model.playbackVolume.setVolume($0) }
        )
    }

    private var currentVolume: Double {
        model.playbackVolume.volume
    }

    private var volumeSymbol: String {
        switch currentVolume {
        case ...0.001: "speaker.slash.fill"
        case ..<0.35: "speaker.wave.1.fill"
        case ..<0.7: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
