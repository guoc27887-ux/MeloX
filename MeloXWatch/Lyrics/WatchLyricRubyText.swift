import SwiftUI

struct WatchLyricRubyText: View {
    let units: [WatchLyricRubyUnit]
    let progress: TimeInterval
    let appliesTimingEffects: Bool
    let fontSize: CGFloat
    let romanizationFontSize: CGFloat
    let romanizationOpacity: Double
    let rendererStyle: WatchLyricRendererStyle
    let preferences: MeloXWatchLyricsPreferences

    var body: some View {
        WatchLyricRubyFlowLayout(
            horizontalSpacing: max(romanizationFontSize * 0.15, 1),
            rowSpacing: max(fontSize * 0.12, 2)
        ) {
            ForEach(units) { unit in
                VStack(spacing: 1) {
                    originalText(for: unit)

                    romanizationText(for: unit)
                        .foregroundStyle(
                            .white.opacity(
                                min(
                                    max(romanizationOpacity, 0),
                                    1
                                )
                            )
                        )
                }
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func originalText(
        for unit: WatchLyricRubyUnit
    ) -> some View {
        if #available(watchOS 11.0, *),
           !unit.originalSyllables.isEmpty {
            WatchTimedLyricTextBuilder.text(
                from: unit.originalSyllables
            )
            .font(font(size: fontSize))
            .fixedSize()
            .textRenderer(
                WatchLyricTextRenderer(
                    playbackTime: progress,
                    style: rendererStyle,
                    appliesTimingEffects: appliesTimingEffects
                )
            )
        } else if !unit.originalSyllables.isEmpty {
            WatchLegacyTimedLyricText(
                syllables: unit.originalSyllables,
                progress: progress,
                appliesTimingEffects: appliesTimingEffects,
                fontSize: fontSize,
                romanization: false,
                preferences: preferences
            )
        } else {
            Text(verbatim: unit.originalText)
                .font(font(size: fontSize))
                .fixedSize()
        }
    }

    @ViewBuilder
    private func romanizationText(
        for unit: WatchLyricRubyUnit
    ) -> some View {
        if #available(watchOS 11.0, *),
           !unit.romanizationSyllables.isEmpty {
            WatchTimedLyricTextBuilder.text(
                from: unit.romanizationSyllables
            )
            .font(font(size: romanizationFontSize))
            .fixedSize()
            .textRenderer(
                WatchLyricRomanizationTextRenderer(
                    playbackTime: progress,
                    unplayedOpacity:
                        rendererStyle.unplayedOpacity,
                    appliesTimingEffects: appliesTimingEffects
                )
            )
        } else if !unit.romanizationSyllables.isEmpty {
            WatchLegacyTimedLyricText(
                syllables: unit.romanizationSyllables,
                progress: progress,
                appliesTimingEffects: appliesTimingEffects,
                fontSize: romanizationFontSize,
                romanization: true,
                preferences: preferences
            )
        } else {
            Text(verbatim: unit.romanizationText)
                .font(font(size: romanizationFontSize))
                .fixedSize()
        }
    }

    private func font(size: CGFloat) -> Font {
        .system(
            size: size,
            weight: .bold,
            design: .rounded
        )
    }
}

private struct WatchLyricRubyFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = layout(
            proposal: proposal,
            subviews: subviews
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
            proposal: ProposedViewSize(
                width: bounds.width,
                height: proposal.height
            ),
            subviews: subviews
        )
        for (index, position) in result.positions.enumerated() {
            guard subviews.indices.contains(index) else { continue }
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> Result {
        let sizes = subviews.map {
            $0.sizeThatFits(.unspecified)
        }
        let naturalWidth = sizes.reduce(CGFloat.zero) {
            $0 + $1.width
        }
        let availableWidth = max(
            proposal.width ?? naturalWidth,
            1
        )
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in sizes {
            let addedWidth = x > 0
                ? horizontalSpacing + size.width
                : size.width
            if x > 0, x + addedWidth > availableWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            } else if x > 0 {
                x += horizontalSpacing
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x)
        }
        return Result(
            positions: positions,
            usedWidth: usedWidth,
            height: sizes.isEmpty ? 0 : y + rowHeight
        )
    }

    private struct Result {
        let positions: [CGPoint]
        let usedWidth: CGFloat
        let height: CGFloat
    }
}
