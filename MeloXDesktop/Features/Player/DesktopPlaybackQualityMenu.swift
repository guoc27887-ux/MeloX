import SwiftUI

/// Keeps every desktop player surface on the same quality-selection behavior.
/// The menu only publishes the preference; the app shell coordinates source
/// replacement so every settings and player surface follows one code path.
struct DesktopPlaybackQualityMenu: View {
    let model: DesktopAppModel

    var body: some View {
        Menu {
            if model.player.availablePlaybackQualities.isEmpty {
                Text("ui.desktop.player.loading_quality")
            } else {
                Picker("ui.player.playback_quality", selection: qualityBinding) {
                    ForEach(model.player.availablePlaybackQualities) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            }
        } label: {
            Label(menuTitle, systemImage: "waveform")
        }
        .disabled(model.player.currentSong == nil)
    }

    private var menuTitle: String {
        if let quality = model.player.effectivePlaybackQuality {
            return L10n.format("ui.desktop.player.quality_value", quality.title)
        }
        return L10n.string("ui.player.playback_quality")
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: {
                model.player.effectivePlaybackQuality
                    ?? model.settings.quality
            },
            set: { model.player.selectPlaybackQuality($0) }
        )
    }
}
