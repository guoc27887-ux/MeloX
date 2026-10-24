import Foundation

nonisolated enum WatchLyricParser {
    static func parse(
        yrc: String,
        lrc: String,
        translatedYRC: String = "",
        translatedLRC: String = "",
        romanizedYRC: String = "",
        romanizedLRC: String = ""
    ) -> [WatchLyricLine] {
        let synchronizedLines = parseYRC(yrc)
        let lineSynchronizedLines = parseLRC(lrc)
        let lines = synchronizedLines.isEmpty
            ? lineSynchronizedLines
            : synchronizedLines
        guard !lines.isEmpty else { return [] }

        let translatedLines = attachSecondaryLyrics(
            synchronizedSource: translatedYRC,
            lineSynchronizedSource: translatedLRC,
            synchronizedOriginalLines: synchronizedLines,
            lineSynchronizedOriginalLines:
                lineSynchronizedLines,
            to: lines,
            kind: .translation
        )
        let romanizedLines = attachSecondaryLyrics(
            synchronizedSource: romanizedYRC,
            lineSynchronizedSource: romanizedLRC,
            synchronizedOriginalLines: synchronizedLines,
            lineSynchronizedOriginalLines:
                lineSynchronizedLines,
            to: translatedLines,
            kind: .romanization
        )
        return attachRomanizationTimings(
            parseYRC(romanizedYRC),
            to: romanizedLines
        )
    }

    static func parseLRC(_ source: String) -> [WatchLyricLine] {
        let expression = try? NSRegularExpression(
            pattern: #"\[(\d+):(\d+(?:[.:]\d+)?)\]"#
        )
        var result: [WatchLyricLine] = []
        for rawLine in source.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let range = NSRange(line.startIndex..., in: line)
            let matches = expression?.matches(in: line, range: range) ?? []
            guard let finalMatch = matches.last else { continue }
            let storage = line as NSString
            let text = storage.substring(
                from: NSMaxRange(finalMatch.range)
            ).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            for match in matches {
                guard let minutes = Int(
                    storage.substring(with: match.range(at: 1))
                ) else {
                    continue
                }
                let secondsString = storage.substring(
                    with: match.range(at: 2)
                ).replacingOccurrences(of: ":", with: ".")
                guard let seconds = Double(secondsString) else { continue }
                result.append(
                    WatchLyricLine(
                        time: Double(minutes) * 60 + seconds,
                        duration: nil,
                        text: text,
                        syllables: [],
                        romanization: nil,
                        romanizationSyllables: [],
                        translation: nil
                    )
                )
            }
        }

        let sorted = result.sorted { $0.time < $1.time }
        return sorted.enumerated().map { index, line in
            let nextTime = index + 1 < sorted.count
                ? sorted[index + 1].time
                : nil
            let inferred = nextTime.map { max($0 - line.time, 0.1) }
                ?? min(max(Double(line.text.count) * 0.32, 2), 8)
            return WatchLyricLine(
                time: line.time,
                duration: inferred,
                text: line.text,
                syllables: [],
                romanization: nil,
                romanizationSyllables: [],
                translation: nil
            )
        }
    }

    static func parseYRC(_ source: String) -> [WatchLyricLine] {
        let syllableExpression = try? NSRegularExpression(
            pattern: #"\((\d+),(\d+),\d+\)"#
        )
        var result: [WatchLyricLine] = []

        for rawLine in source.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.first == "[",
                  let closingBracket = line.firstIndex(of: "]") else {
                continue
            }
            let timing = line[
                line.index(after: line.startIndex)..<closingBracket
            ].split(separator: ",")
            guard timing.count >= 2,
                  let startMS = Int(timing[0]),
                  let durationMS = Int(timing[1]) else {
                continue
            }

            let content = String(line[line.index(after: closingBracket)...])
            let storage = content as NSString
            let matches = syllableExpression?.matches(
                in: content,
                range: NSRange(content.startIndex..., in: content)
            ) ?? []

            if matches.isEmpty {
                let text = content.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                result.append(
                    WatchLyricLine(
                        time: TimeInterval(startMS) / 1_000,
                        duration: TimeInterval(durationMS) / 1_000,
                        text: text,
                        syllables: [],
                        romanization: nil,
                        romanizationSyllables: [],
                        translation: nil
                    )
                )
                continue
            }

            let syllables = matches.enumerated().compactMap {
                index,
                match -> WatchLyricSyllable? in
                guard let syllableStartMS = Int(
                    storage.substring(with: match.range(at: 1))
                ),
                let syllableDurationMS = Int(
                    storage.substring(with: match.range(at: 2))
                ) else {
                    return nil
                }
                let textStart = NSMaxRange(match.range)
                let textEnd = index + 1 < matches.count
                    ? matches[index + 1].range.location
                    : storage.length
                guard textEnd >= textStart else { return nil }
                let text = storage.substring(
                    with: NSRange(
                        location: textStart,
                        length: textEnd - textStart
                    )
                )
                guard !text.isEmpty else { return nil }
                let start = TimeInterval(syllableStartMS) / 1_000
                return WatchLyricSyllable(
                    text: text,
                    startTime: start,
                    endTime: start
                        + TimeInterval(syllableDurationMS) / 1_000
                )
            }
            guard !syllables.isEmpty else { continue }
            result.append(
                WatchLyricLine(
                    time: TimeInterval(startMS) / 1_000,
                    duration: TimeInterval(durationMS) / 1_000,
                    text: syllables.map(\.text).joined(),
                    syllables: syllables,
                    romanization: nil,
                    romanizationSyllables: [],
                    translation: nil
                )
            )
        }
        return result.sorted { $0.time < $1.time }
    }

    static func highlightedIndex(
        at time: TimeInterval,
        in lyrics: [WatchLyricLine]
    ) -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var lower = lyrics.startIndex
        var upper = lyrics.endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lyrics[middle].time <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower > lyrics.startIndex else { return nil }
        let latestStartedIndex = lyrics.index(before: lower)
        let activeIndices = lyrics[..<lower].indices.filter { index in
            let line = lyrics[index]
            guard let duration = line.duration,
                  duration > 0 else {
                return false
            }
            return time < line.time + duration
        }
        if let primaryIndex = activeIndices.last(where: {
            lyrics[$0].isSecondaryVocal != true
        }) {
            return primaryIndex
        }
        return inheritedFocusIndex(
            for: activeIndices.last ?? latestStartedIndex,
            in: lyrics[..<lower]
        )
    }

    static func activeIndices(
        at time: TimeInterval,
        in lyrics: [WatchLyricLine]
    ) -> Set<Int> {
        let active = Set(lyrics.indices.filter { index in
            let line = lyrics[index]
            guard line.time <= time,
                  let duration = line.duration,
                  duration > 0 else {
                return false
            }
            return time < line.time + duration
        })
        if !active.isEmpty {
            return active
        }
        return highlightedIndex(at: time, in: lyrics).map { [$0] } ?? []
    }

    private static func inheritedFocusIndex(
        for targetIndex: Int,
        in startedLyrics: ArraySlice<WatchLyricLine>
    ) -> Int {
        typealias FocusEntry = (
            endTime: TimeInterval,
            ownerIndex: Int,
            isPrimary: Bool
        )
        var overlappingEntries: [FocusEntry] = []

        for index in startedLyrics.indices {
            let line = startedLyrics[index]
            overlappingEntries.removeAll {
                $0.endTime <= line.time
            }

            let isPrimary = line.isSecondaryVocal != true
            let ownerIndex: Int
            if isPrimary {
                ownerIndex = index
            } else if let primaryEntry = overlappingEntries.last(where: {
                $0.isPrimary
            }) {
                ownerIndex = primaryEntry.ownerIndex
            } else {
                ownerIndex = overlappingEntries.last?.ownerIndex ?? index
            }

            if index == targetIndex {
                return ownerIndex
            }

            guard let duration = line.duration,
                  duration > 0 else {
                continue
            }
            overlappingEntries.append(
                (
                    endTime: line.time + duration,
                    ownerIndex: ownerIndex,
                    isPrimary: isPrimary
                )
            )
        }

        return targetIndex
    }

    private static func attachSecondaryLyrics(
        synchronizedSource: String,
        lineSynchronizedSource: String,
        synchronizedOriginalLines: [WatchLyricLine],
        lineSynchronizedOriginalLines: [WatchLyricLine],
        to lines: [WatchLyricLine],
        kind: WatchSecondaryLyricKind
    ) -> [WatchLyricLine] {
        let synchronizedSecondaryLines = parseYRC(
            synchronizedSource
        )
        let synchronizedFallback =
            synchronizedSecondaryLines.isEmpty
                ? parseLRC(synchronizedSource)
                : synchronizedSecondaryLines
        let lineSynchronizedSecondaryLines = parseLRC(
            lineSynchronizedSource
        )

        let directlyAnnotatedLines = attachSecondaryLines(
            synchronizedFallback,
            to: lines,
            kind: kind
        )
        guard !lineSynchronizedSecondaryLines.isEmpty else {
            return directlyAnnotatedLines
        }

        if synchronizedOriginalLines.isEmpty
            || lineSynchronizedOriginalLines.isEmpty {
            return attachSecondaryLines(
                lineSynchronizedSecondaryLines,
                to: directlyAnnotatedLines,
                kind: kind
            )
        }

        let annotatedOriginalLines = attachSecondaryLines(
            lineSynchronizedSecondaryLines,
            to: lineSynchronizedOriginalLines,
            kind: kind
        )
        let canonicallyAnnotatedLines = transferSecondaryLyrics(
            from: annotatedOriginalLines,
            to: directlyAnnotatedLines,
            kind: kind
        )
        return fillMissingSecondaryLyrics(
            in: canonicallyAnnotatedLines,
            from: directlyAnnotatedLines,
            kind: kind
        )
    }

    private static func attachSecondaryLines(
        _ secondaryLines: [WatchLyricLine],
        to lines: [WatchLyricLine],
        kind: WatchSecondaryLyricKind
    ) -> [WatchLyricLine] {
        guard !secondaryLines.isEmpty else { return lines }

        var lineIndex = 0
        var secondaryTextByLineIndex: [Int: String] = [:]
        for secondaryLine in secondaryLines {
            while lineIndex + 1 < lines.count {
                let currentDistance = abs(
                    lines[lineIndex].time - secondaryLine.time
                )
                let nextDistance = abs(
                    lines[lineIndex + 1].time
                        - secondaryLine.time
                )
                let shouldAdvance =
                    nextDistance < currentDistance
                        || (
                            nextDistance == currentDistance
                                && lines[lineIndex]
                                    .syllables.isEmpty
                                && !lines[lineIndex + 1]
                                    .syllables.isEmpty
                        )
                guard shouldAdvance else { break }
                lineIndex += 1
            }

            let line = lines[lineIndex]
            let normalizedSecondaryText =
                secondaryLine.text.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            guard abs(line.time - secondaryLine.time)
                    <= annotationTolerance,
                  !normalizedSecondaryText.isEmpty,
                  normalizedSecondaryText
                    != line.text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                  secondaryTextByLineIndex[lineIndex] == nil else {
                continue
            }
            secondaryTextByLineIndex[lineIndex] =
                normalizedSecondaryText
        }

        return lines.enumerated().map { index, line in
            kind.attaching(
                secondaryTextByLineIndex[index]
                    ?? kind.text(in: line),
                to: line
            )
        }
    }

    private static func attachRomanizationTimings(
        _ romanizedLines: [WatchLyricLine],
        to lines: [WatchLyricLine]
    ) -> [WatchLyricLine] {
        let timedRomanizedLines = romanizedLines.filter {
            !$0.syllables.isEmpty
        }
        guard !timedRomanizedLines.isEmpty else {
            return lines
        }

        var lineIndex = 0
        var romanizedLineByIndex: [Int: WatchLyricLine] = [:]
        for romanizedLine in timedRomanizedLines {
            while lineIndex + 1 < lines.count,
                  abs(
                      lines[lineIndex + 1].time
                          - romanizedLine.time
                  )
                    < abs(
                        lines[lineIndex].time
                            - romanizedLine.time
                    ) {
                lineIndex += 1
            }

            guard abs(
                lines[lineIndex].time - romanizedLine.time
            ) <= annotationTolerance,
            romanizedLineByIndex[lineIndex] == nil else {
                continue
            }
            romanizedLineByIndex[lineIndex] = romanizedLine
        }

        return lines.enumerated().map { index, line in
            guard let romanizedLine =
                romanizedLineByIndex[index] else {
                return line
            }
            var result = line
            result.romanization =
                line.romanization ?? romanizedLine.text
            result.romanizationSyllables =
                romanizedLine.syllables
            return result
        }
    }

    private static func transferSecondaryLyrics(
        from sourceLines: [WatchLyricLine],
        to targetLines: [WatchLyricLine],
        kind: WatchSecondaryLyricKind
    ) -> [WatchLyricLine] {
        guard !sourceLines.isEmpty,
              !targetLines.isEmpty else {
            return targetLines
        }

        var minimumTargetIndex = 0
        var secondaryTextByTargetIndex: [Int: String] = [:]
        for sourceLine in sourceLines {
            guard let secondaryText = kind.text(in: sourceLine),
                  minimumTargetIndex < targetLines.count else {
                continue
            }

            let candidateRange =
                minimumTargetIndex..<targetLines.count
            let normalizedSource = normalizedLyricText(
                sourceLine.text
            )
            let textMatchedIndex = candidateRange
                .filter { index in
                    guard !normalizedSource.isEmpty else {
                        return false
                    }
                    let targetLine = targetLines[index]
                    return abs(
                        targetLine.time - sourceLine.time
                    ) <= textMatchWindow
                        && normalizedLyricText(targetLine.text)
                            == normalizedSource
                }
                .min { left, right in
                    abs(
                        targetLines[left].time - sourceLine.time
                    )
                        < abs(
                            targetLines[right].time
                                - sourceLine.time
                        )
                }

            let targetIndex = textMatchedIndex
                ?? candidateRange
                    .filter { index in
                        let targetLine = targetLines[index]
                        return !targetLine.syllables.isEmpty
                            && abs(
                                targetLine.time
                                    - sourceLine.time
                            ) <= annotationTolerance
                    }
                    .min { left, right in
                        abs(
                            targetLines[left].time
                                - sourceLine.time
                        )
                            < abs(
                                targetLines[right].time
                                    - sourceLine.time
                            )
                    }

            guard let targetIndex else { continue }
            secondaryTextByTargetIndex[targetIndex] =
                secondaryText
            minimumTargetIndex = targetIndex + 1
        }

        return targetLines.enumerated().map { index, line in
            kind.attaching(
                kind.mergedText(
                    synchronizedText: kind.text(in: line),
                    lineSynchronizedText:
                        secondaryTextByTargetIndex[index]
                ),
                to: line
            )
        }
    }

    private static func fillMissingSecondaryLyrics(
        in primaryLines: [WatchLyricLine],
        from fallbackLines: [WatchLyricLine],
        kind: WatchSecondaryLyricKind
    ) -> [WatchLyricLine] {
        guard primaryLines.count == fallbackLines.count else {
            return primaryLines
        }

        return primaryLines.indices.map { index in
            let primaryLine = primaryLines[index]
            let fallbackLine = fallbackLines[index]
            guard kind.text(in: primaryLine) == nil,
                  let fallbackText = kind.text(
                      in: fallbackLine
                  ) else {
                return primaryLine
            }

            let normalizedFallback = normalizedLyricText(
                fallbackText
            )
            let neighboringRange =
                max(index - 1, 0)...min(
                    index + 1,
                    primaryLines.count - 1
                )
            let isDuplicateOfNeighbor =
                neighboringRange.contains { neighborIndex in
                    guard let neighborText = kind.text(
                        in: primaryLines[neighborIndex]
                    ) else {
                        return false
                    }
                    return normalizedLyricText(neighborText)
                        == normalizedFallback
                }
            guard !isDuplicateOfNeighbor else {
                return primaryLine
            }
            return kind.attaching(
                fallbackText,
                to: primaryLine
            )
        }
    }

    private static func normalizedLyricText(
        _ text: String
    ) -> String {
        text
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive,
                ],
                locale: .current
            )
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
    }

    private static let annotationTolerance: TimeInterval = 0.75
    private static let textMatchWindow: TimeInterval = 5
}

private nonisolated enum WatchSecondaryLyricKind {
    case translation
    case romanization

    func text(in line: WatchLyricLine) -> String? {
        switch self {
        case .translation:
            line.translation
        case .romanization:
            line.romanization
        }
    }

    func attaching(
        _ text: String?,
        to line: WatchLyricLine
    ) -> WatchLyricLine {
        var result = line
        switch self {
        case .translation:
            result.translation = text
        case .romanization:
            result.romanization = text
        }
        return result
    }

    func mergedText(
        synchronizedText: String?,
        lineSynchronizedText: String?
    ) -> String? {
        switch self {
        case .translation:
            lineSynchronizedText ?? synchronizedText
        case .romanization:
            // yromalrc may contain pronunciations for parenthetical
            // backing vocals that the older romalrc omits.
            synchronizedText ?? lineSynchronizedText
        }
    }
}
