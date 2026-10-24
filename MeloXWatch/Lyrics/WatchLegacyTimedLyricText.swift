import SwiftUI

struct WatchLegacyTimedLyricText: View {
    let syllables: [WatchLyricSyllable]
    let progress: TimeInterval
    let appliesTimingEffects: Bool
    let fontSize: CGFloat
    let romanization: Bool
    let preferences: MeloXWatchLyricsPreferences

    var body: some View {
        WatchLegacyLyricFlowLayout {
            ForEach(syllables) { syllable in
                WatchLegacyTimedSyllable(
                    syllable: syllable,
                    progress: progress,
                    appliesTimingEffects: appliesTimingEffects,
                    fontSize: fontSize,
                    romanization: romanization,
                    preferences: preferences
                )
            }
        }
    }
}

private struct WatchLegacyTimedSyllable: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let syllable: WatchLyricSyllable
    let progress: TimeInterval
    let appliesTimingEffects: Bool
    let fontSize: CGFloat
    let romanization: Bool
    let preferences: MeloXWatchLyricsPreferences

    var body: some View {
        Text(verbatim: syllable.text)
            .font(font)
            .foregroundStyle(
                .white.opacity(appliesTimingEffects ? 0.3 : 1)
            )
            .fixedSize()
            .overlay {
                if appliesTimingEffects {
                    GeometryReader { proxy in
                        Text(verbatim: syllable.text)
                            .font(font)
                            .foregroundStyle(.white)
                            .fixedSize()
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(
                                        width:
                                            proxy.size.width
                                            * revealProgress
                                    )
                            }
                    }
                }
            }
            .offset(y: verticalOffset)
            .scaleEffect(longToneScale)
            .shadow(
                color:
                    appliesTimingEffects
                        && !romanization
                        && preferences.usesGlow
                        ? .white.opacity(0.35)
                        : .clear,
                radius:
                    appliesTimingEffects
                        && !romanization
                        && preferences.usesGlow
                        ? 4
                        : 0
            )
    }

    private var font: Font {
        .system(
            size: fontSize,
            weight: .bold,
            design: .rounded
        )
    }

    private var verticalOffset: CGFloat {
        guard appliesTimingEffects,
              !romanization,
              !reducesMotion else {
            return 0
        }
        return -min(max(fontSize * 0.1, 1.5), 6)
            * liftProgress
    }

    private var revealProgress: CGFloat {
        guard progress > syllable.startTime else { return 0 }
        guard progress < syllable.endTime else { return 1 }
        let duration = max(
            syllable.endTime - syllable.startTime,
            0.01
        )
        return CGFloat(
            min(
                max(
                    (progress - syllable.startTime) / duration,
                    0
                ),
                1
            )
        )
    }

    private var liftProgress: CGFloat {
        let continuation: TimeInterval = 0.32
        let duration =
            syllable.endTime - syllable.startTime + continuation
        guard duration > 0 else { return 1 }
        let value = min(
            max(
                (progress - syllable.startTime) / duration,
                0
            ),
            1
        )
        return CGFloat(value * value * (3 - 2 * value))
    }

    private var longToneScale: CGFloat {
        guard appliesTimingEffects,
              !romanization,
              !reducesMotion else {
            return 1
        }
        let duration = syllable.endTime - syllable.startTime
        guard duration
                >= preferences.longToneDurationThreshold else {
            return 1
        }
        let animationDuration = max(duration, 1)
        let raw = min(
            max(
                (progress - syllable.startTime) / animationDuration,
                0
            ),
            1
        )
        return 1
            + CGFloat(
                max(preferences.longToneExpansionAmount, 0)
                    * sin(.pi * raw)
            )
    }
}

private struct WatchLegacyLyricFlowLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = layout(
            subviews: subviews,
            availableWidth: proposal.width
        )
        return CGSize(
            width: proposal.width ?? result.usedWidth,
            height: result.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            subviews: subviews,
            availableWidth: bounds.width
        )
        for (index, point) in result.positions.enumerated() {
            guard subviews.indices.contains(index) else { continue }
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + point.x,
                    y: bounds.minY + point.y
                ),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(
        subviews: Subviews,
        availableWidth: CGFloat?
    ) -> Result {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let naturalWidth = sizes.reduce(0) { $0 + $1.width }
        let width = max(availableWidth ?? naturalWidth, 1)
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in sizes {
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x)
        }
        return Result(
            positions: positions,
            usedWidth: usedWidth,
            height: y + rowHeight
        )
    }

    private struct Result {
        let positions: [CGPoint]
        let usedWidth: CGFloat
        let height: CGFloat
    }
}
