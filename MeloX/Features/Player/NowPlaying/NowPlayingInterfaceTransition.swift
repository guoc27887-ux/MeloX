import SwiftUI

enum NowPlayingInterfaceTransition {
    typealias ControlLayer = NowPlayingInterfaceLayer

    private static let motion = NowPlayingMotionSpec.appleMusic26.interface

    static var utilityHiddenOffset: CGFloat {
        motion.utilityHiddenOffset
    }

    static var utilityHiddenScale: CGFloat {
        motion.utilityHiddenScale
    }

    static func interfaceAnimation(
        isVisible: Bool,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        return isVisible
            ? motion.coreShow.animation
            : motion.coreHide.animation
    }

    static func utilityAnimation(
        isVisible: Bool,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        return isVisible
            ? motion.utilityShow.animation
            : motion.utilityHide.animation
    }

    static func hiddenOffset(
        for layer: ControlLayer
    ) -> CGFloat {
        motion.layerMotion(for: layer).hiddenOffset
    }

    static func controlAnimation(
        for layer: ControlLayer,
        isVisible: Bool,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }

        return motion.controlAnimation(
            for: layer,
            isVisible: isVisible
        ).animation
    }
}
