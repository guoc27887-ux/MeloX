import AppKit
import Foundation

enum LyricsLiveActivityCompactLayout {
    static let leadingTextWidth = 38.0
    static let trailingTextWidth = 62.0

    static func requiresScrolling(text: String, pointSize: Double) -> Bool {
        width(of: text, pointSize: pointSize)
            > leadingTextWidth + trailingTextWidth
    }

    static func scrollDistanceToRevealEnd(
        text: String,
        pointSize: Double
    ) -> Double {
        max(
            width(of: text, pointSize: pointSize)
                - leadingTextWidth
                - trailingTextWidth,
            0
        )
    }

    static func width(of text: String, pointSize: Double) -> Double {
        Double(
            (text as NSString).size(
                withAttributes: [
                    .font: NSFont.systemFont(
                        ofSize: pointSize,
                        weight: .semibold
                    )
                ]
            ).width
        )
    }
}
