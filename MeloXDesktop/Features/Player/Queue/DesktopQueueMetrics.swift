import SwiftUI

enum DesktopQueuePresentation: Hashable {
    case inspector
    case nowPlaying
    case miniPlayer
}

struct DesktopQueueMetrics {
    let modeHorizontalPadding: CGFloat
    let modeSpacing: CGFloat
    let modeTopPadding: CGFloat
    let modeHeight: CGFloat
    let headerHorizontalPadding: CGFloat
    let headerHeight: CGFloat
    let rowLeadingInset: CGFloat
    let rowTrailingInset: CGFloat
    let artworkSize: CGFloat
    let rowOuterSpacing: CGFloat
    let rowContentSpacing: CGFloat
    let rowVerticalInset: CGFloat
    let rowTitleFont: Font
    let rowSubtitleFont: Font
    let menuSize: CGFloat
    let clearFont: Font
    let bottomFadeHeight: CGFloat
    let bottomInset: CGFloat
    let usesProminentSelection: Bool

    init(presentation: DesktopQueuePresentation) {
        switch presentation {
        case .nowPlaying:
            modeHorizontalPadding = 9
            modeSpacing = 11
            modeTopPadding = 38
            modeHeight = 38
            headerHorizontalPadding = 15
            headerHeight = 44
            rowLeadingInset = 15
            rowTrailingInset = 9
            artworkSize = 34
            rowOuterSpacing = 8
            rowContentSpacing = 11
            rowVerticalInset = 7
            rowTitleFont = .system(size: 14, weight: .medium)
            rowSubtitleFont = .system(size: 12, weight: .regular)
            menuSize = 28
            clearFont = .system(size: 14, weight: .medium)
            bottomFadeHeight = 72
            bottomInset = 64
            usesProminentSelection = true
        case .inspector:
            modeHorizontalPadding = 9
            modeSpacing = 9
            modeTopPadding = 7
            modeHeight = 38
            headerHorizontalPadding = 16
            headerHeight = 44
            rowLeadingInset = 16
            rowTrailingInset = 10
            artworkSize = 34
            rowOuterSpacing = 8
            rowContentSpacing = 11
            rowVerticalInset = 7
            rowTitleFont = .system(size: 14, weight: .medium)
            rowSubtitleFont = .system(size: 12, weight: .regular)
            menuSize = 28
            clearFont = .system(size: 14, weight: .medium)
            bottomFadeHeight = 72
            bottomInset = 0
            usesProminentSelection = true
        case .miniPlayer:
            modeHorizontalPadding = 12
            modeSpacing = 10
            modeTopPadding = 14
            modeHeight = 32
            headerHorizontalPadding = 12
            headerHeight = 44
            rowLeadingInset = 12
            rowTrailingInset = 8
            artworkSize = 38
            rowOuterSpacing = 8
            rowContentSpacing = 10
            rowVerticalInset = 3
            rowTitleFont = .body
            rowSubtitleFont = .caption
            menuSize = 24
            clearFont = .body
            bottomFadeHeight = 48
            bottomInset = 0
            usesProminentSelection = false
        }
    }
}

enum DesktopQueueSection: String, Hashable {
    case history
    case upcoming
}

struct DesktopQueueEntry: Identifiable {
    let section: DesktopQueueSection
    let queueIndex: Int
    let song: Song

    var id: String {
        "\(section.rawValue)-\(queueIndex)"
    }
}
