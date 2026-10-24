import SwiftUI

/// Resolves the initial playback focus inside the lyrics subtree so the outer
/// player chrome does not observe progress and rebuild open menus every tick.
struct DesktopPlaybackPositionedLyricsView: View {
    @Environment(DesktopAppModel.self) private var model

    var compact = false
    var allowsLyricBlur = true
    var foregroundColor: Color = .primary
    var isActive = true
    var isPresented = true
    var keepsPlaybackFocusSynchronized = false
    var visualScale: CGFloat = 1
    /// Compensates an outer top inset so the focused line stays in Music's
    /// upper-half pretty-mode focus band instead of drifting down with the
    /// padded SwiftUI viewport.
    var focusLift: CGFloat = 0

    private var effectiveVisualScale: CGFloat {
        max(visualScale, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            lyrics
                .frame(
                    width: geometry.size.width / effectiveVisualScale,
                    height: geometry.size.height / effectiveVisualScale
                )
                .scaleEffect(effectiveVisualScale, anchor: .topLeading)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
        }
    }

    private var lyrics: some View {
        DesktopLyricsScrollView(
            compact: compact,
            allowsLyricBlur: allowsLyricBlur,
            foregroundColor: foregroundColor,
            initialFocusID: model.currentLyricsFocusID,
            isActive: isActive,
            isPresented: isPresented,
            keepsPlaybackFocusSynchronized:
                keepsPlaybackFocusSynchronized,
            visualScale: effectiveVisualScale,
            focusLift: focusLift / effectiveVisualScale
        )
    }
}
