import SwiftUI

struct DesktopNowPlayingProgress: View {
    private static let idleTrackHeight: CGFloat = 8
    private static let expandedTrackHeight: CGFloat = 18
    private static let expansionAnimation = Animation.timingCurve(
        0.25,
        0.10,
        0.25,
        1,
        duration: 0.32
    )
    private static let collapseAnimation = Animation.timingCurve(
        0.20,
        0.80,
        0.20,
        1,
        duration: 0.40
    )

    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTrackExpanded = false
    @State private var scrubbedProgress: TimeInterval?
    @State private var inactiveProgress: TimeInterval = 0

    let tint: Color
    let isActive: Bool
    var scale: CGFloat = 1

    private var contentScale: CGFloat {
        max(scale, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            progressSlider

            HStack {
                Text(format(elapsedSecond))
                    .contentTransition(
                        .numericText(value: Double(elapsedSecond))
                    )
                    .transaction { transaction in
                        guard let numericTextAnimation else { return }
                        transaction.animation = numericTextAnimation
                    }

                Spacer()

                Text("−\(format(remainingSecond))")
                    .contentTransition(
                        .numericText(value: Double(remainingSecond))
                    )
                    .transaction { transaction in
                        guard let numericTextAnimation else { return }
                        transaction.animation = numericTextAnimation
                    }
            }
            .font(
                .system(size: 10 * contentScale)
                    .monospacedDigit()
            )
            .foregroundStyle(tint.opacity(0.82))
            .padding(.top, 3 * contentScale)
        }
        .onChange(of: isActive, initial: true) { _, isActive in
            guard !isActive else { return }
            inactiveProgress = model.player.progress
        }
    }

    private var progressSlider: some View {
        ZStack {
            GeometryReader { geometry in
                progressTrack(width: geometry.size.width)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .allowsHitTesting(false)

            hiddenInteractionSlider
                .opacity(0.001)
                .allowsHitTesting(true)
        }
        .frame(height: Self.expandedTrackHeight * contentScale)
        .contentShape(.rect)
    }

    private func progressTrack(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(tint.opacity(0.22))

            Rectangle()
                .fill(tint)
                .frame(width: width * progressFraction)
        }
        .clipShape(.capsule)
        .frame(width: width, height: trackHeight)
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
                get: { displayedProgress },
                set: { value in
                    scrubbedProgress = value
                    model.player.seek(to: value)
                }
            ),
            in: 0...maximumProgress,
            onEditingChanged: setScrubbing
        )
        .controlSize(.large)
        .accessibilityLabel("ui.desktop.player.playback_progress")
        .accessibilityValue(
            "\(format(elapsedSecond)) / \(format(totalSecond))"
        )
    }

    private var displayedProgress: TimeInterval {
        min(
            max(
                scrubbedProgress
                    ?? (isActive ? model.player.progress : inactiveProgress),
                0
            ),
            max(model.player.duration, 0)
        )
    }

    private var maximumProgress: TimeInterval {
        max(model.player.duration, 1)
    }

    private var progressFraction: CGFloat {
        guard maximumProgress > 0 else { return 0 }
        return CGFloat(
            min(max(displayedProgress / maximumProgress, 0), 1)
        )
    }

    private var trackHeight: CGFloat {
        (isTrackExpanded
            ? Self.expandedTrackHeight
            : Self.idleTrackHeight) * contentScale
    }

    private var elapsedSecond: Int {
        max(Int(displayedProgress), 0)
    }

    private var remainingSecond: Int {
        max(Int(max(model.player.duration - displayedProgress, 0)), 0)
    }

    private var totalSecond: Int {
        max(Int(max(model.player.duration, 0)), 0)
    }

    private var numericTextAnimation: Animation? {
        guard !reduceMotion, scrubbedProgress != nil else { return nil }
        return .smooth(duration: 0.18)
    }

    private func setScrubbing(_ scrubbing: Bool) {
        if scrubbing {
            scrubbedProgress = displayedProgress
            setTrackExpanded(true)
        } else {
            if let scrubbedProgress {
                model.player.seek(to: scrubbedProgress)
            }
            scrubbedProgress = nil
            setTrackExpanded(false)
        }
    }

    private func setTrackExpanded(_ expanded: Bool) {
        guard isTrackExpanded != expanded else { return }
        guard !reduceMotion else {
            isTrackExpanded = expanded
            return
        }

        withAnimation(
            expanded
                ? Self.expansionAnimation
                : Self.collapseAnimation
        ) {
            isTrackExpanded = expanded
        }
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
