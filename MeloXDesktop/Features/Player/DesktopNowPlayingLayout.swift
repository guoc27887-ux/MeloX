import CoreGraphics

struct DesktopNowPlayingLayout {
    let viewport: CGSize

    private static let expandedReferenceHeight: CGFloat = 768
    private static let expandedReferenceWidth: CGFloat = 1_200
    /// AX 实测：1239 × 600 时歌词容器 `y=88`，chrome 高 48，因此歌词面板
    /// 在 chrome 之下还有 40pt 顶部留白。
    static let lyricsTopPadding: CGFloat = 40

    private var compactHeightCompression: CGFloat {
        min(max(600 - viewport.height, 0), 50)
    }

    private var heightProgress: CGFloat {
        min(max((viewport.height - 600) / 168, 0), 1)
    }

    /// The original layout stopped growing at 768 points tall. Keep that
    /// layout as the reference size, then let genuinely large windows grow
    /// beyond it. Width participates in the calculation so a narrow, tall
    /// window still leaves useful room for the lyrics panel.
    var elementScale: CGFloat {
        min(
            max(viewport.height / Self.expandedReferenceHeight, 1),
            max(viewport.width / Self.expandedReferenceWidth, 1)
        )
    }

    /// LyricsX does not continuously scale its viewport. `LyricsSpecs` uses
    /// five discrete font breakpoints chosen from the real view width, so the
    /// SwiftUI lyrics surface must keep `visualScale == 1`.
    var chromeHeight: CGFloat { 48 }

    var contentHeight: CGFloat {
        max(viewport.height - chromeHeight, 0)
    }

    /// MusicPlayerController.LyricsViewController constrains its named
    /// `activeBaseline` anchor to
    /// `primaryArtworkCenterY - hostedContentMinY`, and LyricsX positions the
    /// selected line center on that anchor. In window coordinates this means:
    /// focused lyric center == primary artwork center Y.
    var hostedContentMinY: CGFloat {
        chromeHeight + Self.lyricsTopPadding
    }

    var primaryArtworkCenterY: CGFloat {
        chromeHeight + artworkTopInset + artworkSize * 0.5
    }

    var lyricsFocusAnchorOffset: CGFloat {
        max(primaryArtworkCenterY - hostedContentMinY, 0)
    }

    var lyricsViewportHeight: CGFloat {
        max(viewport.height - hostedContentMinY, 0)
    }

    /// Converted to the `focusLift` representation used by
    /// DesktopLyricsScrollView: the distance from the geometric viewport
    /// center up to Music's active-baseline focus anchor.
    var lyricsFocusLift: CGFloat {
        max(
            lyricsViewportHeight * 0.5 - lyricsFocusAnchorOffset,
            0
        )
    }

    var leading: CGFloat {
        max(viewport.width * 0.25 - playerWidth * 0.5, 0)
    }

    var trailing: CGFloat {
        max(32, viewport.width * 0.045)
    }

    var panelSpacing: CGFloat {
        max(viewport.width * 0.5 - leading - playerWidth, 0)
    }

    /// In Music's macOS 26 display mode the alternate page starts on the
    /// exact horizontal midpoint. The player column is centered in the first
    /// half, rather than positioned from a growing heuristic inset.
    var panelLeading: CGFloat {
        viewport.width * 0.5
    }

    var playerWidth: CGFloat {
        (320 + heightProgress * 102) * elementScale
    }

    var artworkSize: CGFloat {
        (214 + heightProgress * 94) * elementScale
    }

    var artworkTopInset: CGFloat {
        (
            54
                - compactHeightCompression
                + heightProgress * 60
        ) * elementScale
    }

    var metadataTopInset: CGFloat {
        (70 + heightProgress * 10) * elementScale
    }
}
