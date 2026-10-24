import SwiftUI

enum WatchLyricsFocusEffects {
    nonisolated static func distanceBlurRadius(
        pixelDistance: CGFloat,
        lyricStride: CGFloat,
        intensity: CGFloat
    ) -> CGFloat {
        let lineDistance = pixelDistance / max(lyricStride, 1)
        let blurProgress = max(lineDistance - 1.35, 0)
        let baseRadius = min(blurProgress * 3.1, 10)
        return baseRadius * max(intensity, 0)
    }

    nonisolated static func focusBlurRadius(
        intensity: CGFloat,
        relativeIndex: Int
    ) -> CGFloat {
        let precedingLineRadius: CGFloat =
            relativeIndex == -1 ? 2.4 : 0
        let followingLineRadius: CGFloat =
            relativeIndex == 1 ? 0.7 : 0
        return (precedingLineRadius + followingLineRadius)
            * max(intensity, 0)
    }

    nonisolated static func opacity(
        pixelDistance: CGFloat,
        lyricStride: CGFloat,
        dimAmount: Double
    ) -> Double {
        let lineDistance = Double(
            pixelDistance / max(lyricStride, 1)
        )
        let baseOpacity: Double
        switch lineDistance {
        case ...1:
            baseOpacity = 1 - lineDistance * 0.44
        case ...2:
            baseOpacity =
                0.56 - (lineDistance - 1) * 0.22
        default:
            baseOpacity = max(
                0.12,
                0.34 - (lineDistance - 2) * 0.07
            )
        }
        let dimAmount = min(max(dimAmount, 0), 1)
        return 1 - (1 - baseOpacity) * dimAmount
    }

    nonisolated static func emphasis(
        isPlaybackLine: Bool,
        dimAmount: Double
    ) -> Double {
        guard !isPlaybackLine else { return 1 }
        let dimAmount = min(max(dimAmount, 0), 1)
        return 1 - (1 - 0.52) * dimAmount
    }
}
