import ActivityKit
import SwiftUI
import WidgetKit

struct LyricsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: LyricsLiveActivityAttributes.self
        ) { context in
            lockScreenContent(context.state)
                .activityBackgroundTint(.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    artwork(context.state, size: 42)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Image(
                        systemName: context.state.isPlaying
                            ? "waveform"
                            : "pause.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(
                    .bottom,
                    priority: 1
                ) {
                    expandedContent(context.state)
                }
            } compactLeading: {
                compactLeadingContent(context.state)
            } compactTrailing: {
                compactTrailingContent(context.state)
            } minimal: {
                artwork(context.state, size: 24)
            }
            .keylineTint(.red)
        }
    }

    private var activitySymbol: some View {
        Image(systemName: "music.note")
            .symbolVariant(.circle.fill)
            .foregroundStyle(.white, .red)
    }

    private func lockScreenContent(
        _ state: LyricsLiveActivityAttributes.ContentState
    ) -> some View {
        HStack(spacing: 14) {
            artwork(state, size: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .contentTransition(.opacity)

                if state.presentation.showsNextLyric,
                   let nextLyric = visibleNextLyric(in: state) {
                    Text(nextLyric)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(
                        systemName: state.isPlaying
                            ? "play.fill"
                            : "pause.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                }

                if state.presentation.showsProgress {
                    playbackProgress(state)
                        .tint(.red)
                }
            }
        }
        .padding(16)
        .animation(.smooth(duration: 0.35), value: state.title)
    }

    private func expandedContent(
        _ state: LyricsLiveActivityAttributes.ContentState
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(state.title)
                .font(.headline)
                .lineLimit(2)
                .contentTransition(.opacity)

            if state.presentation.showsNextLyric,
               let nextLyric = visibleNextLyric(in: state) {
                Text(nextLyric)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(state.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if state.presentation.showsProgress {
                    playbackProgress(state)
                        .frame(width: 76)
                        .tint(.red)
                }
            }
        }
        .padding(.horizontal, 4)
        .animation(.smooth(duration: 0.35), value: state.title)
    }

    @ViewBuilder
    private func playbackProgress(
        _ state: LyricsLiveActivityAttributes.ContentState
    ) -> some View {
        if let interval = state.playbackInterval {
            ProgressView(
                timerInterval: interval,
                countsDown: false
            )
        } else {
            ProgressView(value: state.progress)
        }
    }

    private func visibleNextLyric(
        in state: LyricsLiveActivityAttributes.ContentState
    ) -> String? {
        let lyric = state.nextLyric?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return lyric.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func compactLeadingContent(
        _ state: LyricsLiveActivityAttributes.ContentState
    ) -> some View {
        let textWidth =
            LyricsLiveActivityCompactLayout.leadingTextWidth
        let parts = compactTextParts(in: state)

        return HStack(spacing: 4) {
            artwork(state, size: 19)

            compactRegionContent(
                state,
                width: textWidth,
                trackStartDistance:
                    compactScrollDistance(in: state),
                fallbackText: parts.leading
            )
        }
        .frame(width: 61, alignment: .leading)
    }

    private func compactTrailingContent(
        _ state: LyricsLiveActivityAttributes.ContentState
    ) -> some View {
        let width =
            LyricsLiveActivityCompactLayout.trailingTextWidth
        let parts = compactTextParts(in: state)
        return compactRegionContent(
            state,
            width: width,
            trackStartDistance:
                compactScrollDistance(in: state)
                    + LyricsLiveActivityCompactLayout
                        .leadingTextWidth,
            fallbackText: parts.trailing
        )
    }

    @ViewBuilder
    private func compactRegionContent(
        _ state: LyricsLiveActivityAttributes.ContentState,
        width: Double,
        trackStartDistance: Double,
        fallbackText: String
    ) -> some View {
        let pointSize =
            state.presentation.compactTextSize.pointSize
        let scrolls = state.presentation.scrollsCompactText
            && LyricsLiveActivityCompactLayout.requiresScrolling(
                text: state.compactText,
                pointSize: pointSize
            )

        LiveActivityCompactText(
            text: scrolls ? state.compactText : fallbackText,
            pointSize: pointSize,
            travelDistance:
                scrolls ? CGFloat(trackStartDistance) : 0
        )
        .frame(width: width, height: 18, alignment: .leading)
        .clipped()
        .transaction { transaction in
            if !scrolls || compactScrollDistance(in: state) == 0 {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .animation(
            !scrolls || compactScrollDistance(in: state) == 0
                ? nil
                : .linear(duration: 0.55),
            value: compactScrollDistance(in: state)
        )
    }

    private func compactTextParts(
        in state: LyricsLiveActivityAttributes.ContentState
    ) -> (leading: String, trailing: String) {
        LyricsLiveActivityCompactLayout.visibleParts(
            text: state.compactText,
            pointSize:
                state.presentation.compactTextSize.pointSize,
            scrollOffset: state.compactScrollOffset
        )
    }

    private func compactScrollDistance(
        in state: LyricsLiveActivityAttributes.ContentState
    ) -> Double {
        state.compactScrollDistance
            ?? LyricsLiveActivityCompactLayout.travelDistance(
                text: state.compactText,
                pointSize:
                    state.presentation.compactTextSize.pointSize,
                characterOffset: state.compactScrollOffset
            )
    }

    @ViewBuilder
    private func artwork(
        _ state: LyricsLiveActivityAttributes.ContentState,
        size: CGFloat
    ) -> some View {
        if state.presentation.showsArtwork {
            LyricsLiveActivityArtworkView(
                state: state,
                cornerRadius: size * 0.22
            )
            .frame(width: size, height: size)
        } else {
            activitySymbol
                .font(.system(size: size * 0.62))
                .frame(width: size, height: size)
        }
    }
}
