import CoreGraphics
import Foundation

enum DesktopBottomProgressMetrics {
    /// Previous-commit collapsed progress presentation.
    static let collapsedProgressHorizontalScale: CGFloat = 0.97

    static let hoverInterval: TimeInterval = 1 / 12
    static let moveThrottleMask = 7
    static let stationaryDeadZone: CGFloat = 0.1
    static let activationSpeed: CGFloat = 80

    static let leadingInset: CGFloat = 6
    static let collapsedSliderHeight: CGFloat = 10
    static let expandedSliderHeight: CGFloat = 32
    static let collapsedBarHeight: CGFloat = 2
    static let expandedBarHeight: CGFloat = 7
    static let collapsedBarBottom: CGFloat = 4
    static let expandedBarBottom: CGFloat = 7

    static let timeMinimumWidth: CGFloat = 40
    static let collapsedTimeInset: CGFloat = 6
    static let hiddenTimeScale: CGFloat = 0.9
    static let hiddenTimeOffset: CGFloat = 6
    static let visibleTimeOffset: CGFloat = 1

    static let metadataBlurRadius: CGFloat = 3
    static let metadataMaskStops = [0.0, 0.5, 1.0]
    static let metadataMaskAlphas = [0.3, 0.5, 1.0]

    static func sliderHeight(expanded: Bool) -> CGFloat {
        expanded ? expandedSliderHeight : collapsedSliderHeight
    }

    static func barHeight(expanded: Bool) -> CGFloat {
        expanded ? expandedBarHeight : collapsedBarHeight
    }

    static func barBottom(expanded: Bool) -> CGFloat {
        expanded ? expandedBarBottom : collapsedBarBottom
    }
}
