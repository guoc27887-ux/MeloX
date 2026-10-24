import Foundation
import UIKit

enum LyricsLiveActivityCompactLayout {
    static let leadingTextWidth = 38.0
    static let trailingTextWidth = 62.0

    static func requiresScrolling(
        text: String,
        pointSize: Double
    ) -> Bool {
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

    static func characterOffset(
        text: String,
        pointSize: Double,
        travelDistance: Double
    ) -> Int {
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }

        let distance = max(travelDistance, 0)
        var accumulatedWidth = 0.0
        for (index, character) in characters.enumerated() {
            accumulatedWidth += characterWidth(
                character,
                pointSize: pointSize
            )
            if accumulatedWidth > distance {
                return index
            }
        }
        return characters.count
    }

    static func travelDistance(
        text: String,
        pointSize: Double,
        characterOffset: Int
    ) -> Double {
        let characters = Array(text)
        let endIndex = min(
            max(characterOffset, characters.startIndex),
            characters.endIndex
        )
        return characters[..<endIndex].reduce(0) {
            $0 + characterWidth($1, pointSize: pointSize)
        }
    }

    static func pageOffset(
        text: String,
        pointSize: Double,
        travelDistance: Double
    ) -> Int {
        let desiredOffset = characterOffset(
            text: text,
            pointSize: pointSize,
            travelDistance: travelDistance
        )
        return pageOffsets(
            text: text,
            pointSize: pointSize
        )
        .last(where: { $0 <= desiredOffset })
            ?? 0
    }

    static func visibleParts(
        text: String,
        pointSize: Double,
        scrollOffset: Int
    ) -> (leading: String, trailing: String) {
        guard requiresScrolling(
            text: text,
            pointSize: pointSize
        ) else {
            return balancedParts(
                of: text,
                pointSize: pointSize
            )
        }

        let characters = Array(text)
        guard !characters.isEmpty else { return ("", "") }
        var index = min(
            max(scrollOffset, characters.startIndex),
            characters.endIndex
        )
        let leading = segment(
            in: characters,
            index: &index,
            maximumWidth: leadingTextWidth,
            pointSize: pointSize
        )
        let trailing = segment(
            in: characters,
            index: &index,
            maximumWidth: trailingTextWidth,
            pointSize: pointSize
        )
        return (leading, trailing)
    }

    static func width(
        of text: String,
        pointSize: Double
    ) -> Double {
        Double(
            (text as NSString).size(
                withAttributes: [
                    .font: UIFont.systemFont(
                        ofSize: pointSize,
                        weight: .semibold
                    )
                ]
            ).width
        )
    }

    private static func balancedParts(
        of text: String,
        pointSize: Double
    ) -> (leading: String, trailing: String) {
        let characters = Array(text)
        guard characters.count > 1 else {
            return ("", text)
        }

        let widths = characters.map {
            characterWidth($0, pointSize: pointSize)
        }
        let totalWidth = widths.reduce(0, +)
        let totalAvailableWidth =
            leadingTextWidth + trailingTextWidth
        let targetLeadingWidth =
            totalWidth * leadingTextWidth / totalAvailableWidth

        var accumulatedWidth = 0.0
        var bestIndex = 1
        var bestDistance = Double.greatestFiniteMagnitude
        for index in 1..<characters.count {
            accumulatedWidth += widths[index - 1]
            let distance = abs(
                accumulatedWidth - targetLeadingWidth
            )
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        return (
            String(characters[..<bestIndex]),
            String(characters[bestIndex...])
        )
    }

    private static func segment(
        in characters: [Character],
        index: inout Int,
        maximumWidth: Double,
        pointSize: Double
    ) -> String {
        var result = ""
        var resultWidth = 0.0
        var visitedCount = 0

        while index < characters.endIndex,
              visitedCount < characters.count {
            let character = characters[index]
            let characterWidth = characterWidth(
                character,
                pointSize: pointSize
            )
            if !result.isEmpty,
               resultWidth + characterWidth > maximumWidth {
                break
            }

            result.append(character)
            resultWidth += characterWidth
            index += 1
            visitedCount += 1
        }
        return result
    }

    private static func visibleEndIndex(
        in characters: [Character],
        startingAt startIndex: Int,
        pointSize: Double
    ) -> Int {
        var index = startIndex
        index = endIndex(
            in: characters,
            startingAt: index,
            maximumWidth: leadingTextWidth,
            pointSize: pointSize
        )
        return endIndex(
            in: characters,
            startingAt: index,
            maximumWidth: trailingTextWidth,
            pointSize: pointSize
        )
    }

    private static func pageOffsets(
        text: String,
        pointSize: Double
    ) -> [Int] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [0] }

        var finalStartIndex = characters.startIndex
        for startIndex in characters.indices {
            if visibleEndIndex(
                in: characters,
                startingAt: startIndex,
                pointSize: pointSize
            ) >= characters.endIndex {
                finalStartIndex = startIndex
                break
            }
        }

        var result = [characters.startIndex]
        var startIndex = characters.startIndex
        while startIndex < finalStartIndex {
            let visibleEnd = visibleEndIndex(
                in: characters,
                startingAt: startIndex,
                pointSize: pointSize
            )
            let nextStart = min(
                max(visibleEnd, startIndex + 1),
                finalStartIndex
            )
            result.append(nextStart)
            startIndex = nextStart
        }
        return result
    }

    private static func endIndex(
        in characters: [Character],
        startingAt startIndex: Int,
        maximumWidth: Double,
        pointSize: Double
    ) -> Int {
        var index = startIndex
        var usedWidth = 0.0

        while index < characters.endIndex {
            let nextWidth = characterWidth(
                characters[index],
                pointSize: pointSize
            )
            if index > startIndex,
               usedWidth + nextWidth > maximumWidth {
                break
            }
            usedWidth += nextWidth
            index += 1
        }
        return index
    }

    private static func characterWidth(
        _ character: Character,
        pointSize: Double
    ) -> Double {
        width(
            of: String(character),
            pointSize: pointSize
        )
    }
}
