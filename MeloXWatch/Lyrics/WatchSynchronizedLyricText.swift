import SwiftUI

struct WatchSynchronizedLyricText: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let line: WatchLyricLine
    let progress: TimeInterval
    let isHighlighted: Bool
    let isVocalActive: Bool
    let fontSize: CGFloat
    let preferences: MeloXWatchLyricsPreferences

    private let activeSyllables: [WatchLyricSyllable]
    private let rubyUnits: [WatchLyricRubyUnit]

    init(
        line: WatchLyricLine,
        progress: TimeInterval,
        isHighlighted: Bool,
        isVocalActive: Bool? = nil,
        fontSize: CGFloat,
        preferences: MeloXWatchLyricsPreferences
    ) {
        self.line = line
        self.progress = progress
        self.isHighlighted = isHighlighted
        let resolvedIsVocalActive = isVocalActive ?? isHighlighted
        self.isVocalActive = resolvedIsVocalActive
        self.fontSize = fontSize
        self.preferences = preferences

        let activeSyllables = resolvedIsVocalActive
            ? line.effectiveSyllables
            : line.syllables
        self.activeSyllables = activeSyllables
        rubyUnits = resolvedIsVocalActive
            && preferences.showsRomanization
            ? WatchLyricRomanizationAligner.units(
                for: line,
                activeSyllables: activeSyllables
            )
            : []
    }

    var body: some View {
        Group {
            if !isVocalActive {
                staticText
            } else if preferences.showsRomanization,
                      !rubyUnits.isEmpty {
                WatchLyricRubyText(
                    units: rubyUnits,
                    progress: progress,
                    appliesTimingEffects: appliesTimingEffects,
                    fontSize: fontSize,
                    romanizationFontSize: romanizationFontSize,
                    romanizationOpacity:
                        preferences.romanizationOpacity,
                    rendererStyle: rendererStyle,
                    preferences: preferences
                )
            } else {
                primaryText
            }
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }

    private var staticText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: line.text)
                .font(primaryFont)
                .fixedSize(horizontal: false, vertical: true)

            if preferences.showsRomanization,
               let romanization = line.romanization,
               !romanization.isEmpty {
                Text(verbatim: romanization)
                    .font(
                        .system(
                            size: romanizationFontSize,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .opacity(
                        min(
                            max(preferences.romanizationOpacity, 0),
                            1
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var primaryText: some View {
        if #available(watchOS 11.0, *), !activeSyllables.isEmpty {
            WatchTimedLyricTextBuilder.text(from: activeSyllables)
                .font(primaryFont)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textRenderer(
                    WatchLyricTextRenderer(
                        playbackTime: progress,
                        style: rendererStyle,
                        appliesTimingEffects:
                            appliesTimingEffects
                    )
                )
        } else if !activeSyllables.isEmpty {
            WatchLegacyTimedLyricText(
                syllables: activeSyllables,
                progress: progress,
                appliesTimingEffects: appliesTimingEffects,
                fontSize: fontSize,
                romanization: false,
                preferences: preferences
            )
        } else {
            Text(verbatim: line.text)
                .font(primaryFont)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryFont: Font {
        .system(
            size: fontSize,
            weight: .bold,
            design: .rounded
        )
    }

    private var appliesTimingEffects: Bool {
        isVocalActive && preferences.usesWordByWordHighlight
    }

    private var romanizationFontSize: CGFloat {
        max(
            fontSize
                * CGFloat(preferences.romanizationFontScale),
            9
        )
    }

    private var rendererStyle: WatchLyricRendererStyle {
        let expansionAmount = reducesMotion
            ? 0
            : max(preferences.longToneExpansionAmount, 0)
        let glowRadius = preferences.usesGlow
            ? fontSize
                * 0.2
                * CGFloat(preferences.glowIntensity)
            : 0
        return WatchLyricRendererStyle(
            glowRadius: glowRadius,
            glowOpacity:
                preferences.usesGlow
                    ? min(max(preferences.glowIntensity, 0), 1)
                    : 0,
            glowsLongTonesOnly: true,
            unplayedOpacity: 0.3,
            maximumUnplayedBlurRadius:
                CGFloat(max(preferences.blurIntensity, 0))
                    * 0.55,
            playedRise:
                reducesMotion
                    ? 0
                    : min(max(fontSize * 0.1, 1.5), 6),
            maximumLongToneScale:
                1 + CGFloat(expansionAmount),
            longToneExpansionPadding:
                fontSize * CGFloat(expansionAmount) * 1.2,
            highlightGradientWidth: 0.7,
            highlightGradientReduction: 0.65,
            liftMode:
                WatchLyricTimingMode(
                    rawValue: preferences.liftModeRawValue
                ) ?? .character,
            longToneDetectionMode:
                WatchLyricTimingMode(
                    rawValue:
                        preferences.longToneDetectionModeRawValue
                ) ?? .character,
            longToneDurationThreshold:
                max(preferences.longToneDurationThreshold, 0)
        )
    }
}
