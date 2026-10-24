import SwiftUI

/// Previous-commit seek bar style: 2pt idle / 8pt expanded track centered in
/// a 14pt interaction strip, with pressed scaling and horizontal
/// compensation for the collapsed metadata slot scale.
struct DesktopBottomSeekBar: View {
    private static let idleTrackHeight: CGFloat = 2
    private static let expandedTrackHeight: CGFloat = 8

    @Environment(DesktopAppModel.self) private var model
    let isExpanded: Bool
    let isPressed: Bool

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                progressTrack(width: geometry.size.width)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .allowsHitTesting(false)

            hiddenInteractionSlider
                .opacity(0.001)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressTrack(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(trackOpacity))

            Rectangle()
                .fill(.primary.opacity(fillOpacity))
                .frame(width: width * progressFraction)
        }
        .clipShape(.capsule)
        .frame(width: width, height: trackHeight)
        .scaleEffect(
            x: isExpanded
                ? 1
                : 1 / DesktopBottomProgressMetrics
                    .collapsedProgressHorizontalScale,
            y: isPressed ? 1.14 : 1
        )
    }

    @ViewBuilder
    private var hiddenInteractionSlider: some View {
        if #available(macOS 26.0, *) {
            interactionSlider.sliderThumbVisibility(.hidden)
        } else {
            interactionSlider
        }
    }

    private var interactionSlider: some View {
        Slider(
            value: Binding(
                get: {
                    min(
                        model.player.progress,
                        max(model.player.duration, 0)
                    )
                },
                set: { model.player.seek(to: $0) }
            ),
            in: 0...max(model.player.duration, 1)
        )
        .controlSize(.large)
        .accessibilityLabel("ui.desktop.player.playback_progress")
    }

    private var progressFraction: CGFloat {
        let duration = max(model.player.duration, 0)
        guard duration > 0 else { return 0 }
        return CGFloat(
            min(max(model.player.progress / duration, 0), 1)
        )
    }

    private var trackHeight: CGFloat {
        isExpanded
            ? Self.expandedTrackHeight
            : Self.idleTrackHeight
    }

    private var trackOpacity: Double {
        isExpanded ? 0.30 : 0.24
    }

    private var fillOpacity: Double {
        isExpanded ? 0.86 : 0.70
    }
}
