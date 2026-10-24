import SwiftUI

private struct NowPlayingLyricsPagePresentationModifier: ViewModifier {
    let visualState: NowPlayingPageVisualState
    let opacityTransition: NowPlayingInterruptibleProgress
    let spatialTransition: NowPlayingInterruptibleSpringProgress
    let opacitySpec: NowPlayingAnimationSpec
    let presentationScale: CGFloat
    let reducesMotion: Bool

    func body(content: Content) -> some View {
        TimelineView(
            .animation(
                paused:
                    reducesMotion
                    || !opacityTransition.isAnimating
                        && !spatialTransition.isAnimating
            )
        ) { _ in
            let now = ContinuousClock.now
            let opacityProgress = reducesMotion
                ? opacityTransition.targetProgress
                : opacityTransition.progress(at: now)
            let spatialProgress = reducesMotion
                ? spatialTransition.targetProgress
                : spatialTransition.presentation(at: now).progress
            let scale = presentationScale
                + (1 - presentationScale) * CGFloat(spatialProgress)

            content
                .offset(y: visualState.offsetY)
                .scaleEffect(scale)
                .blur(radius: visualState.blurRadius)
                .opacity(
                    opacitySpec.transformedProgress(opacityProgress)
                )
        }
    }
}

extension View {
    func nowPlayingLyricsPagePresentation(
        visualState: NowPlayingPageVisualState,
        opacityTransition: NowPlayingInterruptibleProgress,
        spatialTransition: NowPlayingInterruptibleSpringProgress,
        opacitySpec: NowPlayingAnimationSpec,
        presentationScale: CGFloat,
        reducesMotion: Bool
    ) -> some View {
        modifier(
            NowPlayingLyricsPagePresentationModifier(
                visualState: visualState,
                opacityTransition: opacityTransition,
                spatialTransition: spatialTransition,
                opacitySpec: opacitySpec,
                presentationScale: presentationScale,
                reducesMotion: reducesMotion
            )
        )
    }

    func nowPlayingQueuePagePresentation(
        visualState: NowPlayingPageVisualState,
        opacityTransition: NowPlayingInterruptibleProgress,
        spatialTransition: NowPlayingInterruptibleSpringProgress,
        opacitySpec: NowPlayingAnimationSpec,
        presentationScale: CGFloat,
        reducesMotion: Bool
    ) -> some View {
        modifier(
            NowPlayingLyricsPagePresentationModifier(
                visualState: visualState,
                opacityTransition: opacityTransition,
                spatialTransition: spatialTransition,
                opacitySpec: opacitySpec,
                presentationScale: presentationScale,
                reducesMotion: reducesMotion
            )
        )
    }
}
