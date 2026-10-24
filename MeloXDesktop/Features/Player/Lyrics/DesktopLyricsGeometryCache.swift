import CoreGraphics

/// Keeps transient layout measurements out of SwiftUI's invalidation graph.
///
/// Lyric frames change continuously while a scroll view moves or its window is
/// resized. They are inputs to focus calculations, but they are not render
/// state by themselves, so publishing every measurement would unnecessarily
/// rebuild the complete lyric hierarchy.
@MainActor
final class DesktopLyricsGeometryCache {
    struct FrameUpdate {
        let frameChanged: Bool
        let layoutHeightChanged: Bool
    }

    private(set) var frameByID: [LyricLine.ID: CGRect] = [:]
    private(set) var interludeFrameByID: [LyricInterlude.ID: CGRect] = [:]
    private(set) var layoutHeightByID: [LyricLine.ID: CGFloat] = [:]
    private(set) var annotationHeightByID: [LyricLine.ID: CGFloat] = [:]
    private(set) var viewportSize: CGSize = .zero
    private var lastNotifiedViewportSize: CGSize = .zero
    private var pendingLayoutSynchronization: Task<Void, Never>?
    private var pendingViewportSettlement: Task<Void, Never>?

    /// Returns `true` only for a meaningful change after the initial size has
    /// been recorded. This lets the view debounce live-resize correction
    /// without treating its first layout pass as a resize.
    @discardableResult
    func recordViewportSize(_ size: CGSize) -> Bool {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else { return false }
        let previousSize = viewportSize
        viewportSize = size
        guard previousSize.width > 0, previousSize.height > 0 else {
            lastNotifiedViewportSize = size
            return false
        }
        let notificationSize = lastNotifiedViewportSize.width > 0
            && lastNotifiedViewportSize.height > 0
            ? lastNotifiedViewportSize
            : previousSize
        let hasMeaningfulChange =
            abs(notificationSize.width - size.width) >= 0.5
            || abs(notificationSize.height - size.height) >= 0.5
        guard hasMeaningfulChange else { return false }
        lastNotifiedViewportSize = size
        return true
    }

    func recordFrame(
        _ frame: CGRect,
        for id: LyricLine.ID
    ) -> FrameUpdate? {
        guard frame.minY.isFinite,
              frame.maxY.isFinite,
              frame.height.isFinite,
              frame.height > 0 else { return nil }

        let previousFrame = frameByID[id]
        let previousHeight = layoutHeightByID[id]
        let frameChanged = previousFrame == nil
            || !Self.isApproximatelyEqual(previousFrame ?? .zero, frame)
        let layoutHeightChanged = previousHeight == nil
            || abs((previousHeight ?? 0) - frame.height) > 0.5
        guard frameChanged || layoutHeightChanged else { return nil }

        frameByID[id] = frame
        layoutHeightByID[id] = frame.height
        return FrameUpdate(
            frameChanged: frameChanged,
            layoutHeightChanged: layoutHeightChanged
        )
    }

    func recordAnnotationHeight(
        _ height: CGFloat,
        for id: LyricLine.ID
    ) -> Bool {
        guard height.isFinite, height > 0 else { return false }
        let previousHeight = annotationHeightByID[id]
        guard previousHeight == nil
                || abs((previousHeight ?? 0) - height) > 0.5 else {
            return false
        }

        annotationHeightByID[id] = height
        return true
    }

    func recordInterludeFrame(
        _ frame: CGRect,
        for id: LyricInterlude.ID
    ) {
        guard frame.minY.isFinite,
              frame.maxY.isFinite,
              frame.height.isFinite,
              frame.height > 0 else {
            interludeFrameByID.removeValue(forKey: id)
            return
        }
        let previousFrame = interludeFrameByID[id]
        guard previousFrame == nil
                || !Self.isApproximatelyEqual(previousFrame ?? .zero, frame)
        else {
            return
        }
        interludeFrameByID[id] = frame
    }

    func removeMeasurements(for id: LyricLine.ID) {
        frameByID.removeValue(forKey: id)
        layoutHeightByID.removeValue(forKey: id)
        annotationHeightByID.removeValue(forKey: id)
    }

    func removeInterludeMeasurements(for id: LyricInterlude.ID) {
        interludeFrameByID.removeValue(forKey: id)
    }

    func removeAllMeasurements() {
        cancelPendingLayoutSynchronization()
        cancelPendingViewportSettlement()
        frameByID.removeAll(keepingCapacity: true)
        interludeFrameByID.removeAll(keepingCapacity: true)
        layoutHeightByID.removeAll(keepingCapacity: true)
        annotationHeightByID.removeAll(keepingCapacity: true)
    }

    func cancelPendingLayoutSynchronization() {
        pendingLayoutSynchronization?.cancel()
        pendingLayoutSynchronization = nil
    }

    func cancelPendingViewportSettlement() {
        pendingViewportSettlement?.cancel()
        pendingViewportSettlement = nil
    }

    /// Debounces live window-resize events without publishing every viewport
    /// size through SwiftUI state. The final callback performs one alignment
    /// after AppKit has stopped changing the window geometry.
    func scheduleViewportSettlement(
        after delay: Duration,
        _ action: @escaping @MainActor () -> Void
    ) {
        pendingViewportSettlement?.cancel()
        pendingViewportSettlement = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
            self?.pendingViewportSettlement = nil
        }
    }

    /// Coalesces layout-derived state changes and runs them after the current
    /// AppKit layout pass. Updating SwiftUI state directly from a geometry
    /// callback can recursively enter `layoutSubtreeIfNeeded` while a window
    /// is being resized.
    func scheduleLayoutSynchronization(
        _ action: @escaping @MainActor () -> Void
    ) {
        pendingLayoutSynchronization?.cancel()
        pendingLayoutSynchronization = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            action()
            self?.pendingLayoutSynchronization = nil
        }
    }

    private static func isApproximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect
    ) -> Bool {
        let tolerance: CGFloat = 0.5
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
