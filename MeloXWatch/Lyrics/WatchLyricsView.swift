import SwiftUI

struct WatchLyricsView: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @ScaledMetric(relativeTo: .headline)
    private var lyricFontSize: CGFloat = 18

    let lyrics: [WatchLyricLine]
    let progress: TimeInterval
    let preferences: MeloXWatchLyricsPreferences
    let onSeek: (WatchLyricLine) -> Void

    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0
    @State private var selectedLyricID: WatchLyricLine.ID?
    @State private var scrollPositionID: Int?

    private var highlightedIndex: Int? {
        WatchLyricParser.highlightedIndex(
            at: progress,
            in: lyrics
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let focusPosition = min(
                max(CGFloat(preferences.focusPosition), 0.12),
                0.5
            )
            let focusAnchorY = min(
                geometry.size.height * focusPosition
                    + toolbarFocusClearance,
                geometry.size.height * 0.68
            )
            let scrollFocusPosition = min(
                max(
                    focusAnchorY
                        / max(geometry.size.height, 1),
                    0.12
                ),
                0.68
            )
            let lyricStride = estimatedLyricStride
            let uniformBrowsing =
                isBrowsingLyrics
                    && preferences
                        .usesUniformDimmingWhileBrowsing
            let activeBlurIntensity = uniformBrowsing
                ? 0
                : CGFloat(max(preferences.blurIntensity, 0))
            let activeDistanceDimAmount = uniformBrowsing
                ? 0
                : min(max(preferences.dimAmount, 0), 1)
            let scrollAnchor = UnitPoint(
                x: 0.5,
                y: scrollFocusPosition
            )
            let highlightedIndex = self.highlightedIndex
            let activeIndices = WatchLyricParser.activeIndices(
                at: progress,
                in: lyrics
            )

            browsingAware(
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(lyrics.indices, id: \.self) { index in
                            let line = lyrics[index]
                            let relativeIndex = highlightedIndex.map {
                                index - $0
                            } ?? 0
                            let isPrimaryFocus =
                                index == highlightedIndex
                            let isVocalActive =
                                activeIndices.contains(index)
                            let isActiveIndependentVocalLine =
                                isVocalActive
                                && !isPrimaryFocus
                                && line.isSecondaryVocal == true
                            let isInactiveFocusOwner =
                                isPrimaryFocus && !isVocalActive
                            let focusBlurRadius =
                                WatchLyricsFocusEffects
                                    .focusBlurRadius(
                                        intensity: activeBlurIntensity,
                                        relativeIndex: relativeIndex
                                    )

                            WatchLyricPressInteraction(
                                isSelected:
                                    selectedLyricID == line.id,
                                onTap: {
                                    browsingGeneration &+= 1
                                    isBrowsingLyrics = false
                                    selectedLyricID = line.id
                                    onSeek(line)
                                }
                            ) { backgroundProgress in
                                WatchLyricLineView(
                                    line: line,
                                    progress:
                                        isVocalActive ? progress : 0,
                                    isHighlighted: isPrimaryFocus,
                                    isVocalActive: isVocalActive,
                                    fontSize: lyricFontSize,
                                    interactionBackgroundProgress:
                                        backgroundProgress,
                                    preferences: preferences
                                )
                            }
                            .compositingGroup()
                            .opacity(
                                isActiveIndependentVocalLine
                                    ? 1
                                    : WatchLyricsFocusEffects.emphasis(
                                        isPlaybackLine:
                                            isPrimaryFocus
                                            && !isInactiveFocusOwner,
                                        dimAmount: min(
                                            max(preferences.dimAmount, 0),
                                            1
                                        )
                                    )
                            )
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(
                                    in: .scrollView(axis: .vertical)
                                )
                                let distance = abs(
                                    frame.minY - focusAnchorY
                                )
                                return content
                                    .blur(
                                        radius:
                                            isActiveIndependentVocalLine
                                            ? 0
                                            : WatchLyricsFocusEffects
                                                .distanceBlurRadius(
                                                    pixelDistance:
                                                        distance,
                                                    lyricStride:
                                                        lyricStride,
                                                    intensity:
                                                        activeBlurIntensity
                                                        * CGFloat(
                                                            max(
                                                                preferences
                                                                    .distanceBlurScale,
                                                                0
                                                            )
                                                        )
                                                )
                                    )
                                    .opacity(
                                        isActiveIndependentVocalLine
                                            ? 1
                                            : WatchLyricsFocusEffects
                                                .opacity(
                                                    pixelDistance:
                                                        distance,
                                                    lyricStride:
                                                        lyricStride,
                                                    dimAmount:
                                                        activeDistanceDimAmount
                                                )
                                    )
                            }
                            .blur(
                                radius:
                                    isPrimaryFocus
                                        && !isInactiveFocusOwner
                                        || isActiveIndependentVocalLine
                                        ? 0
                                        : focusBlurRadius
                            )
                            .scaleEffect(
                                isPrimaryFocus && !isInactiveFocusOwner
                                    ? CGFloat(
                                        max(
                                            preferences
                                                .currentLineScale,
                                            1
                                        )
                                    )
                                    : 1,
                                anchor: .topLeading
                            )
                            .animation(
                                rowAnimation(
                                    distance: abs(relativeIndex),
                                    relativeIndex: relativeIndex
                                ),
                                value: highlightedIndex
                            )
                            .padding(.bottom, lineSpacing)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(
                        .top,
                        max(
                            focusAnchorY,
                            28
                        )
                    )
                    .padding(
                        .bottom,
                        max(
                            geometry.size.height
                                - focusAnchorY,
                            44
                        )
                    )
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .scrollPosition(
                    id: $scrollPositionID,
                    anchor: scrollAnchor
                )
                .mask {
                    LinearGradient(
                        stops: [
                            .init(
                                color: .clear,
                                location: 0
                            ),
                            .init(
                                color: .black,
                                location: 0.08
                            ),
                            .init(
                                color: .black,
                                location: 0.86
                            ),
                            .init(
                                color: .clear,
                                location: 1
                            ),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width + 40)
                },
                onIdle: {
                    schedulePlaybackFollowing()
                }
            )
            .onChange(of: highlightedIndex) { _, _ in
                followPlayback(animated: true)
            }
            .onChange(of: lyrics.first?.id) { _, _ in
                isBrowsingLyrics = false
                positionInitialFocus()
            }
            .onAppear {
                positionInitialFocus()
            }
            .onDisappear {
                browsingGeneration &+= 1
            }
            .task(id: selectedLyricID) {
                guard let selectedLyricID else { return }
                do {
                    try await Task.sleep(
                        for: .milliseconds(520)
                    )
                } catch {
                    return
                }
                if self.selectedLyricID
                    == selectedLyricID {
                    self.selectedLyricID = nil
                }
            }
        }
    }

    @ViewBuilder
    private func browsingAware<Content: View>(
        _ content: Content,
        onIdle: @escaping () -> Void
    ) -> some View {
        if #available(watchOS 11.0, *) {
            content.onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking, .interacting:
                    browsingGeneration &+= 1
                    isBrowsingLyrics = true
                case .idle:
                    onIdle()
                case .decelerating, .animating:
                    break
                }
            }
        } else {
            content
        }
    }

    private func positionInitialFocus() {
        guard let highlightedIndex,
              lyrics.indices.contains(highlightedIndex) else {
            return
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPositionID = highlightedIndex
        }
    }

    private func followPlayback(animated: Bool) {
        guard !isBrowsingLyrics,
              let highlightedIndex,
              lyrics.indices.contains(highlightedIndex) else {
            return
        }
        let targetID = highlightedIndex
        guard animated, !reducesMotion else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                scrollPositionID = targetID
            }
            return
        }
        withAnimation(
            .smooth(
                duration: focusScrollDuration(
                    for: highlightedIndex
                )
            )
        ) {
            scrollPositionID = targetID
        }
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics else { return }
        browsingGeneration &+= 1
        let generation = browsingGeneration
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2.6))
            } catch {
                return
            }
            guard generation == browsingGeneration else { return }
            isBrowsingLyrics = false
            followPlayback(animated: true)
        }
    }

    private var lineSpacing: CGFloat {
        16
    }

    private var toolbarFocusClearance: CGFloat {
        min(max(lyricFontSize * 1.8, 30), 36)
    }

    private var estimatedLyricStride: CGFloat {
        var height = lyricFontSize * 1.2 + lineSpacing
        if preferences.showsRomanization {
            height += max(
                lyricFontSize
                    * CGFloat(preferences.romanizationFontScale),
                9
            ) * 1.2 + 2
        }
        if preferences.showsTranslation {
            height += 13
        }
        if lyrics.contains(where: { $0.backgroundVocal != nil }) {
            height += lyricFontSize * 0.63 * 1.2
                + min(15, max(lyricFontSize * 0.45, 6))
        }
        return max(height, 1)
    }

    private func focusScrollDuration(
        for highlightedIndex: Int
    ) -> TimeInterval {
        let availableDuration: TimeInterval?
        if lyrics.indices.contains(highlightedIndex + 1) {
            availableDuration = max(
                lyrics[highlightedIndex + 1].time
                    - lyrics[highlightedIndex].time,
                0
            )
        } else {
            availableDuration =
                lyrics[highlightedIndex].duration
        }
        guard let availableDuration else { return 0.3 }
        return min(max(availableDuration * 0.35, 0.05), 0.3)
    }

    private func rowAnimation(
        distance: Int,
        relativeIndex: Int
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        if distance == 0, preferences.focusScaleBounceEnabled {
            return lyricSpring(
                duration:
                    preferences.focusScaleBounceDuration,
                bounce: preferences.focusScaleBounce
            )
        }

        let distanceProgress = min(Double(distance) / 6, 1)
        let bounce = preferences.focusCascadeBounceEnabled
            ? preferences.focusCascadeBounce
                * (
                    1
                        - preferences.focusCascadeBounceGradient
                            * distanceProgress
                )
            : 0
        let incrementalCount = max(distance - 1, 0)
        let incrementalDelay =
            Double(incrementalCount * (incrementalCount + 1))
                * 0.5
                * preferences.focusCascadeDelayIncrease
        let followingDelay = relativeIndex > 0
            ? preferences.focusCascadeFollowingDelay
            : 0
        let delay = Double(min(distance, 6))
            * preferences.focusCascadeDelay
            + incrementalDelay
            + followingDelay
        return lyricSpring(
            duration: preferences.focusCascadeDuration,
            bounce: bounce
        )
        .delay(delay)
    }

    private func lyricSpring(
        duration: TimeInterval,
        bounce: Double
    ) -> Animation {
        .spring(
            duration: duration,
            bounce: bounce,
            blendDuration:
                min(max(duration * 0.22, 0.06), 0.14)
        )
    }
}

private struct WatchLyricLineView: View {
    let line: WatchLyricLine
    let progress: TimeInterval
    let isHighlighted: Bool
    let isVocalActive: Bool
    let fontSize: CGFloat
    let interactionBackgroundProgress: Double
    let preferences: MeloXWatchLyricsPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if line.backgroundVocal?.position == .beforePrimary {
                backgroundVocalContent
                    .padding(.bottom, backgroundVocalSpacing)
            }

            primaryVocalContent

            if line.backgroundVocal?.position == .afterPrimary {
                backgroundVocalContent
                    .padding(.top, backgroundVocalSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            if interactionBackgroundProgress > 0 {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    .white.opacity(
                        0.12
                            * min(
                                max(
                                    interactionBackgroundProgress,
                                    0
                                ),
                                1
                            )
                    )
                )
                .padding(-8)
                .allowsHitTesting(false)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("ui.watch.lyrics.seek_hint")
    }

    private var primaryVocalContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            WatchSynchronizedLyricText(
                line: line,
                progress: progress,
                isHighlighted: isHighlighted,
                isVocalActive: isVocalActive,
                fontSize: fontSize,
                preferences: preferences
            )

            if preferences.showsTranslation,
               let translation = line.translation,
               !translation.isEmpty {
                Text(verbatim: translation)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        .white.opacity(isVocalActive ? 0.85 : 0.7)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var backgroundVocalContent: some View {
        if let backgroundVocal = line.backgroundVocal {
            let backgroundLine = backgroundVocal.lyricLine()
            VStack(alignment: .leading, spacing: 2) {
                WatchSynchronizedLyricText(
                    line: backgroundLine,
                    progress: progress,
                    isHighlighted: false,
                    isVocalActive: isVocalActive,
                    fontSize: fontSize * 0.63,
                    preferences: preferences
                )

                if preferences.showsTranslation,
                   let translation = backgroundVocal.translation,
                   !translation.isEmpty {
                    Text(verbatim: translation)
                        .font(.system(size: max(fontSize * 0.36, 8)))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            .white.opacity(isHighlighted ? 0.85 : 0.7)
                        )
                }
            }
            .scaleEffect(
                isHighlighted ? 1 : 0.9,
                anchor: .topLeading
            )
        }
    }

    private var backgroundVocalSpacing: CGFloat {
        min(15, max(fontSize * 0.45, 6))
    }

    private var accessibilityText: String {
        [
            line.text,
            line.romanization,
            line.translation,
            line.backgroundVocal?.text,
            line.backgroundVocal?.translation,
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .localizedList
    }
}

private extension Array where Element == String {
    var localizedList: String {
        L10n.list(self)
    }
}
