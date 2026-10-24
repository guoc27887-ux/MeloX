import CoreGraphics

enum DesktopLyricsLayoutMetrics {
    private static let compactLineSpacingScale: CGFloat = 22.0 / 48.0
    private static let textLayoutWidthQuantum: CGFloat = 4
    private static let visualFocusAnchorQuantum: CGFloat = 2

    static func lineSpacing(
        setting: Double,
        compact: Bool,
        usesAppleMusicMotion: Bool
    ) -> CGFloat {
        let spacing = CGFloat(setting)
        // Music keeps its recovered 39-point paragraph interval in the
        // 258-point inspector. Only MeloX's legacy editable spacing is
        // compressed for compact surfaces.
        if usesAppleMusicMotion { return spacing }
        guard compact else { return spacing }
        return max(spacing * compactLineSpacingScale, 22)
    }

    /// Keeps expensive timed-text and ruby layout cache keys stable while a
    /// window is live-resized. Four-point width steps are visually
    /// indistinguishable here and avoid rebuilding every visible lyric for
    /// every single-point resize event.
    static func textLayoutWidth(
        viewportWidth: CGFloat,
        compact: Bool
    ) -> CGFloat {
        // LyricsX installs a 20-point interface inset on both horizontal
        // edges in both compact and full player presentations.
        let horizontalInset: CGFloat = 40
        let availableWidth = max(viewportWidth - horizontalInset, 1)
        let quantizedWidth = (
            availableWidth / textLayoutWidthQuantum
        ).rounded(.down) * textLayoutWidthQuantum
        return max(quantizedWidth, 1)
    }

    /// Distance blur only needs a visually stable focal point. Quantizing it
    /// prevents height-only live-resize events from invalidating every row.
    static func visualFocusAnchorY(
        viewportHeight: CGFloat,
        focusPosition: CGFloat
    ) -> CGFloat {
        quantizedVisualFocusAnchorY(
            max(viewportHeight, 0) * focusPosition
        )
    }

    static func quantizedVisualFocusAnchorY(
        _ anchorY: CGFloat
    ) -> CGFloat {
        return (
            anchorY / visualFocusAnchorQuantum
        ).rounded() * visualFocusAnchorQuantum
    }
}
