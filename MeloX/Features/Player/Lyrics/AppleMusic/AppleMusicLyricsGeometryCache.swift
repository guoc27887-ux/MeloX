import CoreGraphics

/// Scroll geometry changes every frame. Keeping it outside Observation lets
/// motion code sample the latest positions without invalidating the entire
/// lyrics view on every scroll tick.
@MainActor
final class AppleMusicLyricsGeometryCache {
    var frames: [LyricLine.ID: CGRect] = [:]
    var layoutHeights: [LyricLine.ID: CGFloat] = [:]
    var annotationHeights: [LyricLine.ID: CGFloat] = [:]
    var interludeFrames: [LyricInterlude.ID: CGRect] = [:]

    func remove(_ id: LyricLine.ID) {
        frames.removeValue(forKey: id)
        layoutHeights.removeValue(forKey: id)
        annotationHeights.removeValue(forKey: id)
    }

    func removeInterlude(_ id: LyricInterlude.ID) {
        interludeFrames.removeValue(forKey: id)
    }

    func removeAll() {
        frames.removeAll(keepingCapacity: true)
        layoutHeights.removeAll(keepingCapacity: true)
        annotationHeights.removeAll(keepingCapacity: true)
        interludeFrames.removeAll(keepingCapacity: true)
    }
}
