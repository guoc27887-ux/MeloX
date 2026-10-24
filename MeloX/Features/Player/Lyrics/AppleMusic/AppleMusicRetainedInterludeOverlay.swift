import SwiftUI

struct AppleMusicRetainedInterludePresentation: Identifiable, Equatable {
    let id = UUID()
    let interlude: LyricInterlude
    let frame: CGRect
}

/// Fallback for an interrupted/forced handoff: keeps the instrumental dots at
/// their viewport position while the lyric stack moves underneath them.
struct AppleMusicRetainedInterludeOverlay: View {
    private let motionProfile = AppleMusicInterludeMotionProfile.iOS26_6

    @Environment(PlayerStore.self) private var player

    let presentation: AppleMusicRetainedInterludePresentation
    let isAnimationActive: Bool
    let advanceTime: TimeInterval
    let onFinished: (AppleMusicRetainedInterludePresentation.ID) -> Void

    var body: some View {
        AppleMusicLyricInterludeView(
            interlude: presentation.interlude,
            isVisible: true,
            isAnimationActive: isAnimationActive,
            advanceTime: advanceTime,
            onInterfaceInteraction: nil
        )
        .frame(
            width: max(presentation.frame.width, 0),
            height: motionProfile.viewHeight,
            alignment: .leading
        )
        .offset(
            x: presentation.frame.minX,
            y: presentation.frame.minY
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: lifecycleTrigger) {
            await finishAtAbsoluteVisualEnd()
        }
    }

    private var lifecycleTrigger: LifecycleTrigger {
        LifecycleTrigger(
            presentationID: presentation.id,
            songID: player.currentSong?.id,
            seekRevision: player.seekRevision,
            isPlaying: player.isPlaying,
            isAnimationActive: isAnimationActive,
            advanceTime: advanceTime
        )
    }

    private func finishAtAbsoluteVisualEnd() async {
        guard isAnimationActive else { return }
        let timing = motionProfile.timing(for: presentation.interlude)

        while !Task.isCancelled {
            let playbackTime = player.estimatedProgress() + advanceTime
            guard playbackTime >= timing.cueOutTime,
                  playbackTime < timing.visualEndTime else {
                onFinished(presentation.id)
                return
            }
            guard player.isPlaying else { return }

            do {
                try await Task.sleep(
                    for: .seconds(timing.visualEndTime - playbackTime)
                )
            } catch {
                return
            }
        }
    }
}

private struct LifecycleTrigger: Hashable {
    let presentationID: AppleMusicRetainedInterludePresentation.ID
    let songID: Int?
    let seekRevision: Int
    let isPlaying: Bool
    let isAnimationActive: Bool
    let advanceTime: TimeInterval
}
