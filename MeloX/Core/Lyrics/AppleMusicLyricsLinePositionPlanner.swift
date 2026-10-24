import Foundation

/// Pure reconstruction of Apple Music 26.6's line-position cascade.
///
/// The source line-view manager only visits mounted rows spanning the union
/// of the current and target viewports. It assigns order in lyric order for a
/// forward content-offset change and in reverse lyric order for a negative
/// change. Whether a row actually receives an animation descriptor remains a
/// caller concern so an unchanged mounted row still retains its native order.
nonisolated enum AppleMusicLyricsLinePositionPlanner {
    nonisolated struct PlannedLine<ID: Hashable>: Hashable {
        let id: ID
        let order: Int
        let delay: TimeInterval
    }

    static func plan<ID: Hashable>(
        mountedIDsInLyricOrder: [ID],
        currentViewportIDs: Set<ID>,
        targetViewportIDs: Set<ID>,
        contentOffsetDelta: Double
    ) -> [PlannedLine<ID>] {
        let viewportUnion = currentViewportIDs.union(targetViewportIDs)
        guard let firstIndex = mountedIDsInLyricOrder.firstIndex(
            where: viewportUnion.contains
        ),
            let lastIndex = mountedIDsInLyricOrder.lastIndex(
                where: viewportUnion.contains
            ),
            firstIndex <= lastIndex else {
            return []
        }

        let participatingIDs = mountedIDsInLyricOrder[
            firstIndex...lastIndex
        ]
        let normalizedDelta = abs(contentOffsetDelta) < 1
            ? 0
            : contentOffsetDelta
        let isReverse = normalizedDelta < 0
        let delayStep: TimeInterval = isReverse ? 0.025 : 0.05
        let lastOrder = participatingIDs.count - 1

        return participatingIDs.enumerated().map { index, id in
            let order = isReverse ? lastOrder - index : index
            return PlannedLine(
                id: id,
                order: order,
                delay: TimeInterval(max(order - 1, 0)) * delayStep
            )
        }
    }
}
