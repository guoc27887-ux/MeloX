import CoreGraphics

/// Keeps source-viewport lyric rows renderable while a non-adjacent scroll
/// retargets the lazy stack. Rows that remain in the destination viewport do
/// not need a retained copy because `LazyVStack` keeps their resident view.
nonisolated enum AppleMusicRetainedViewportPlanner {
    nonisolated struct RetainedLyric<ID: Hashable>:
        Identifiable,
        Equatable
    {
        let id: ID
        let frame: CGRect
        let movementDistance: CGFloat
    }

    static func retainedLyrics<ID: Hashable>(
        isNonAdjacentTransition: Bool,
        initialVisibleIDs: [ID],
        framesByID: [ID: CGRect],
        movementDistance: CGFloat,
        destinationOffsetsByID: [ID: CGFloat],
        viewportHeight: CGFloat
    ) -> [RetainedLyric<ID>] {
        guard isNonAdjacentTransition,
              movementDistance.isFinite,
              movementDistance != 0,
              viewportHeight.isFinite,
              viewportHeight > 0 else {
            return []
        }

        return initialVisibleIDs.compactMap { id in
            guard let frame = framesByID[id],
                  isValid(frame),
                  destinationOffsetsByID[id, default: 0].isFinite else {
                return nil
            }

            let destinationOffset =
                -movementDistance
                + destinationOffsetsByID[id, default: 0]
            let leavesDestinationViewport = movementDistance > 0
                ? frame.maxY + destinationOffset <= 0
                : frame.minY + destinationOffset >= viewportHeight
            guard leavesDestinationViewport else { return nil }

            return RetainedLyric(
                id: id,
                frame: frame,
                movementDistance: movementDistance
            )
        }
    }

    private static func isValid(_ frame: CGRect) -> Bool {
        !frame.isNull
            && !frame.isInfinite
            && !frame.isEmpty
            && frame.minY.isFinite
            && frame.maxY.isFinite
    }
}
