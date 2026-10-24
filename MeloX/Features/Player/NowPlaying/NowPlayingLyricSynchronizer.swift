import SwiftUI

struct NowPlayingLyricSynchronizer: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let lyrics: [LyricLine]
    @Binding var highlightedLyricID: LyricLine.ID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: player.progress, initial: true) {
                synchronizeImmediately()
            }
            .task(id: synchronizationTrigger) {
                await synchronizeAtLyricTransitions()
            }
    }

    private var synchronizationTrigger: LyricSynchronizationTrigger {
        let advanceTime = settings.effectiveLyricsAdvanceTime(
            for: lyrics
        )
        return LyricSynchronizationTrigger(
            songID: player.currentSong?.id,
            seekRevision: player.seekRevision,
            isPlaying: player.isPlaying,
            advanceTime: advanceTime,
            lyricCount: lyrics.count,
            firstLyricID: lyrics.first?.id,
            lastLyricID: lyrics.last?.id
        )
    }

    private func synchronizeImmediately() {
        let advanceTime = settings.effectiveLyricsAdvanceTime(
            for: lyrics
        )
        let position = LyricPlaybackTimeline.position(
            at: player.estimatedProgress() + advanceTime,
            in: lyrics
        )
        updateHighlightedLyric(to: position.highlightedLyricID)
    }

    private func synchronizeAtLyricTransitions() async {
        let synchronizedLyrics = lyrics
        let advanceTime = settings.effectiveLyricsAdvanceTime(
            for: synchronizedLyrics
        )

        while !Task.isCancelled {
            let adjustedProgress = player.estimatedProgress() + advanceTime
            let position = LyricPlaybackTimeline.position(
                at: adjustedProgress,
                in: synchronizedLyrics
            )
            updateHighlightedLyric(to: position.highlightedLyricID)

            guard player.isPlaying,
                  let nextTransitionTime = position.nextTransitionTime else {
                return
            }

            let remainingTime = nextTransitionTime
                - (player.estimatedProgress() + advanceTime)
            guard remainingTime > 0 else {
                await Task.yield()
                continue
            }

            do {
                try await Task.sleep(for: .seconds(remainingTime))
            } catch {
                return
            }
        }
    }

    private func updateHighlightedLyric(to lyricID: LyricLine.ID?) {
        guard highlightedLyricID != lyricID else { return }
        highlightedLyricID = lyricID
    }
}

private struct LyricSynchronizationTrigger: Hashable {
    let songID: Int?
    let seekRevision: Int
    let isPlaying: Bool
    let advanceTime: TimeInterval
    let lyricCount: Int
    let firstLyricID: LyricLine.ID?
    let lastLyricID: LyricLine.ID?
}
