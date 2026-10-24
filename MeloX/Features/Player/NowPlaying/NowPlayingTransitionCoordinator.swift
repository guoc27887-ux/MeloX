import Foundation

struct NowPlayingTransitionContext: Equatable, Identifiable, Sendable {
    let id: UUID
    let source: NowPlayingPage
    let destination: NowPlayingPage
    let isDirectLyricsQueueTransition: Bool
    let entersFromHiddenQueue: Bool
    let usesStagedLyricsEntrance: Bool
    let interruptsLyricsExit: Bool

    init(
        id: UUID = UUID(),
        source: NowPlayingPage,
        destination: NowPlayingPage,
        entersFromHiddenQueue: Bool,
        usesStagedLyricsEntrance: Bool,
        interruptsLyricsExit: Bool
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        isDirectLyricsQueueTransition =
            source == .lyrics && destination == .queue
            || source == .queue && destination == .lyrics
        self.entersFromHiddenQueue = entersFromHiddenQueue
        self.usesStagedLyricsEntrance = usesStagedLyricsEntrance
        self.interruptsLyricsExit = interruptsLyricsExit
    }
}

struct NowPlayingPendingLyricsEntrance: Equatable, Sendable {
    let requestID: UUID
    let notBefore: ContinuousClock.Instant
    let fallbackAt: ContinuousClock.Instant
}

struct NowPlayingTransitionCoordinator: Equatable {
    enum LyricsEntrancePhase: Equatable {
        case presented
        case pending(NowPlayingPendingLyricsEntrance)

        var isPresented: Bool {
            switch self {
            case .presented:
                true
            case .pending:
                false
            }
        }
    }

    private(set) var page: NowPlayingPage
    private(set) var transition: NowPlayingTransitionContext?
    private(set) var lyricsEntrancePhase: LyricsEntrancePhase = .presented
    private(set) var lyricsOpacityTransition:
        NowPlayingInterruptibleProgress
    private(set) var lyricsSpatialTransition:
        NowPlayingInterruptibleSpringProgress
    private(set) var queueOpacityTransition:
        NowPlayingInterruptibleProgress
    private(set) var queueSpatialTransition:
        NowPlayingInterruptibleSpringProgress

    init(
        initialPage: NowPlayingPage,
        motion: NowPlayingMotionSpec.PageMotion =
            NowPlayingMotionSpec.appleMusic26.page,
        now: ContinuousClock.Instant = .now
    ) {
        page = initialPage
        lyricsOpacityTransition = .settled(
            at: initialPage == .lyrics ? 1 : 0,
            now: now
        )
        lyricsSpatialTransition = .settled(
            at: initialPage == .lyrics ? 1 : 0,
            animationSpec: motion.lyricsSpatialPresentation,
            now: now
        )
        queueOpacityTransition = .settled(
            at: initialPage == .queue ? 1 : 0,
            now: now
        )
        queueSpatialTransition = .settled(
            at: initialPage == .queue ? 1 : 0,
            animationSpec: motion.queueSpatialPresentation,
            now: now
        )
    }

    var sourcePage: NowPlayingPage {
        transition?.source ?? page
    }

    var destinationPage: NowPlayingPage {
        transition?.destination ?? page
    }

    var entersFromHiddenQueue: Bool {
        transition?.entersFromHiddenQueue == true
    }

    var interruptsLyricsExit: Bool {
        transition?.interruptsLyricsExit == true
    }

    var usesStagedLyricsEntrance: Bool {
        transition?.usesStagedLyricsEntrance == true
    }

    var isLyricsEntrancePresented: Bool {
        lyricsEntrancePhase.isPresented
    }

    var pendingLyricsEntrance: NowPlayingPendingLyricsEntrance? {
        guard case let .pending(entrance) =
            lyricsEntrancePhase else {
            return nil
        }
        return entrance
    }

    func activeMotionRemainingDuration(
        at now: ContinuousClock.Instant = .now
    ) -> TimeInterval {
        max(
            lyricsOpacityTransition.remainingDuration(at: now),
            lyricsSpatialTransition.remainingDuration(at: now),
            queueOpacityTransition.remainingDuration(at: now),
            queueSpatialTransition.remainingDuration(at: now)
        )
    }

    mutating func select(
        _ destination: NowPlayingPage,
        usesAppleMusicLyrics: Bool,
        isQueueSongHeaderHidden: Bool,
        motion: NowPlayingMotionSpec.PageMotion,
        now: ContinuousClock.Instant = .now
    ) {
        let source = page
        guard source != destination else { return }

        let startsLyricsEntrance =
            source != .lyrics
            && destination == .lyrics
            && usesAppleMusicLyrics
        let currentOpacityProgress = lyricsOpacityTransition.progress(
            at: now
        )
        let interruptsActiveLyricsExit =
            startsLyricsEntrance
            && lyricsOpacityTransition.targetProgress < 1
            && currentOpacityProgress > 0.000_1
        let requestID = UUID()
        let context = NowPlayingTransitionContext(
            id: requestID,
            source: source,
            destination: destination,
            entersFromHiddenQueue:
                source == .queue
                && isQueueSongHeaderHidden
                && destination != .queue,
            usesStagedLyricsEntrance:
                startsLyricsEntrance
                && !interruptsActiveLyricsExit,
            interruptsLyricsExit: interruptsActiveLyricsExit
        )

        let currentQueueOpacity = queueOpacityTransition.progress(
            at: now
        )
        if destination == .queue {
            let reversesQueueExit =
                queueOpacityTransition.targetProgress < 1
                && currentQueueOpacity > 0.000_1
            queueOpacityTransition = queueOpacityTransition.retargeted(
                to: 1,
                fullDuration: motion.queueOpacityPresentation.duration,
                now: now,
                delay:
                    reversesQueueExit
                        ? 0
                        : motion.queueOpacityPresentation.delay
            )
            queueSpatialTransition = queueSpatialTransition.retargeted(
                to: 1,
                animationSpec: motion.queueSpatialPresentation,
                now: now
            )
        } else if source == .queue {
            queueOpacityTransition = queueOpacityTransition.retargeted(
                to: 0,
                fullDuration: motion.queueOpacityDismissal.duration,
                now: now
            )
            queueSpatialTransition = queueSpatialTransition.retargeted(
                to: 0,
                animationSpec: motion.queueSpatialDismissal,
                now: now
            )
        }

        if !usesAppleMusicLyrics {
            lyricsEntrancePhase = .presented
            lyricsOpacityTransition = .settled(
                at: destination == .lyrics ? 1 : 0,
                now: now
            )
            lyricsSpatialTransition = .settled(
                at: destination == .lyrics ? 1 : 0,
                animationSpec: motion.lyricsSpatialPresentation,
                now: now
            )
        } else if context.usesStagedLyricsEntrance {
            lyricsEntrancePhase = .pending(
                NowPlayingPendingLyricsEntrance(
                    requestID: requestID,
                    notBefore: now.advanced(
                        by: .seconds(motion.lyricsPresentationDelay)
                    ),
                    fallbackAt: now.advanced(
                        by: .seconds(
                            motion.lyricsReadinessFallbackDelay
                        )
                    )
                )
            )
            lyricsOpacityTransition = .settled(at: 0, now: now)
            lyricsSpatialTransition = .settled(
                at: 0,
                animationSpec: motion.lyricsSpatialPresentation,
                now: now
            )
        } else {
            lyricsEntrancePhase = .presented
            if destination == .lyrics {
                lyricsOpacityTransition = lyricsOpacityTransition
                    .retargeted(
                        to: 1,
                        fullDuration:
                            motion.lyricsOpacityPresentation.duration,
                        now: now
                    )
                lyricsSpatialTransition = lyricsSpatialTransition
                    .retargeted(
                        to: 1,
                        animationSpec:
                            motion.lyricsSpatialPresentation,
                        now: now
                    )
            } else if source == .lyrics {
                lyricsOpacityTransition = lyricsOpacityTransition
                    .retargeted(
                        to: 0,
                        fullDuration:
                            motion.lyricsOpacityDismissal.duration,
                        now: now
                    )
                lyricsSpatialTransition = lyricsSpatialTransition
                    .retargeted(
                        to: 0,
                        animationSpec:
                            motion.lyricsSpatialDismissal,
                        now: now
                    )
            }
        }

        transition = context
        page = destination
    }

    mutating func presentLyricsEntrance(
        requestID: UUID,
        motion: NowPlayingMotionSpec.PageMotion,
        now: ContinuousClock.Instant = .now
    ) {
        guard transition?.id == requestID,
              transition?.usesStagedLyricsEntrance == true,
              case let .pending(entrance) = lyricsEntrancePhase,
              entrance.requestID == requestID else {
            return
        }
        lyricsEntrancePhase = .presented
        lyricsOpacityTransition = lyricsOpacityTransition.retargeted(
            to: 1,
            fullDuration: motion.lyricsOpacityPresentation.duration,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.retargeted(
            to: 1,
            animationSpec: motion.lyricsSpatialPresentation,
            now: now
        )
    }

    mutating func settleTransition(
        requestID: UUID,
        now: ContinuousClock.Instant = .now
    ) {
        guard transition?.id == requestID,
              lyricsEntrancePhase.isPresented else {
            return
        }
        transition = nil
        lyricsOpacityTransition = .settled(
            at: lyricsOpacityTransition.targetProgress,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.settled(
            at: lyricsSpatialTransition.targetProgress,
            now: now
        )
        queueOpacityTransition = .settled(
            at: queueOpacityTransition.targetProgress,
            now: now
        )
        queueSpatialTransition = queueSpatialTransition.settled(
            at: queueSpatialTransition.targetProgress,
            now: now
        )
    }

    mutating func synchronizeLyricsVisibility(
        isVisible: Bool,
        now: ContinuousClock.Instant = .now
    ) {
        transition = nil
        lyricsEntrancePhase = .presented
        lyricsOpacityTransition = .settled(
            at: isVisible ? 1 : 0,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.settled(
            at: isVisible ? 1 : 0,
            now: now
        )
        queueOpacityTransition = .settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
        queueSpatialTransition = queueSpatialTransition.settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
    }

    mutating func reset(
        to page: NowPlayingPage,
        now: ContinuousClock.Instant = .now
    ) {
        self.page = page
        transition = nil
        lyricsEntrancePhase = .presented
        lyricsOpacityTransition = .settled(
            at: page == .lyrics ? 1 : 0,
            now: now
        )
        lyricsSpatialTransition = lyricsSpatialTransition.settled(
            at: page == .lyrics ? 1 : 0,
            now: now
        )
        queueOpacityTransition = .settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
        queueSpatialTransition = queueSpatialTransition.settled(
            at: page == .queue ? 1 : 0,
            now: now
        )
    }
}
