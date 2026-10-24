import Foundation

struct WatchLyricRubyUnit: Identifiable, Hashable {
    let id: Int
    let originalText: String
    let originalSyllables: [WatchLyricSyllable]
    let romanizationText: String
    let romanizationSyllables: [WatchLyricSyllable]
}

@MainActor
enum WatchLyricRomanizationAligner {
    private static var cache: [CacheKey: [WatchLyricRubyUnit]] = [:]
    private static var insertionOrder: [CacheKey] = []
    private static let cacheCapacity = 256

    static func units(
        for line: WatchLyricLine,
        activeSyllables: [WatchLyricSyllable]
    ) -> [WatchLyricRubyUnit] {
        guard let romanization = normalized(line.romanization) else {
            return []
        }

        let key = CacheKey(
            originalText: line.text,
            romanization: romanization,
            originalSyllables: activeSyllables,
            romanizationSyllables: line.romanizationSyllables
        )
        if let cached = cache[key] {
            return cached
        }

        let drafts: [UnitDraft]
        if let timed = timedUnits(
            originals: activeSyllables,
            romanizations: line.romanizationSyllables
        ) {
            drafts = timed
        } else if let segmented = segmentedUnits(
            originalText: line.text,
            originalSyllables: activeSyllables,
            romanization: romanization
        ) {
            drafts = segmented
        } else {
            drafts = [
                makeUnit(
                    originalText: line.text,
                    originalSyllables: activeSyllables,
                    romanization: romanization
                ),
            ]
        }

        let result = drafts.enumerated().map { index, draft in
            WatchLyricRubyUnit(
                id: index,
                originalText: draft.originalText,
                originalSyllables: draft.originalSyllables,
                romanizationText: draft.romanizationText,
                romanizationSyllables: draft.romanizationSyllables
            )
        }
        insert(result, for: key)
        return result
    }

    private static func timedUnits(
        originals: [WatchLyricSyllable],
        romanizations: [WatchLyricSyllable]
    ) -> [UnitDraft]? {
        let originals = originals.filter { !$0.text.isEmpty }
        let romanizations = romanizations.filter {
            normalized($0.text) != nil
        }
        guard !originals.isEmpty, !romanizations.isEmpty else {
            return nil
        }

        if originals.count == romanizations.count,
           zip(originals, romanizations).allSatisfy({
               temporalDistance($0.0, $0.1)
                    <= timingTolerance(for: $0.0, and: $0.1)
           }) {
            return zip(originals, romanizations).map {
                original,
                romanization in
                makeUnit(
                    originalText: original.text,
                    originalSyllables: [original],
                    romanization: romanization.text
                )
            }
        }

        if originals.count >= romanizations.count {
            return unitsByMappingOriginals(
                originals,
                to: romanizations
            )
        }
        return unitsByMappingRomanizations(
            romanizations,
            to: originals
        )
    }

    private static func unitsByMappingOriginals(
        _ originals: [WatchLyricSyllable],
        to romanizations: [WatchLyricSyllable]
    ) -> [UnitDraft]? {
        let mapping = originals.map {
            bestTimedMatch(for: $0, in: romanizations)
        }
        guard mapping.allSatisfy({ $0 != nil }) else { return nil }
        let indices = mapping.compactMap { $0 }
        guard indices == indices.sorted(),
              Set(indices) == Set(romanizations.indices) else {
            return nil
        }

        var result: [UnitDraft] = []
        var lowerBound = originals.startIndex
        while lowerBound < originals.endIndex {
            let romanizationIndex = indices[lowerBound]
            var upperBound = lowerBound + 1
            while upperBound < originals.endIndex,
                  indices[upperBound] == romanizationIndex {
                upperBound += 1
            }

            let group = Array(originals[lowerBound..<upperBound])
            result.append(
                makeUnit(
                    originalText: group.map(\.text).joined(),
                    originalSyllables: group,
                    romanization: romanizations[romanizationIndex].text
                )
            )
            lowerBound = upperBound
        }
        return result
    }

    private static func unitsByMappingRomanizations(
        _ romanizations: [WatchLyricSyllable],
        to originals: [WatchLyricSyllable]
    ) -> [UnitDraft]? {
        let mapping = romanizations.map {
            bestTimedMatch(for: $0, in: originals)
        }
        guard mapping.allSatisfy({ $0 != nil }) else { return nil }
        let indices = mapping.compactMap { $0 }
        guard indices == indices.sorted(),
              Set(indices) == Set(originals.indices) else {
            return nil
        }

        var romanizationsByOriginal: [Int: [WatchLyricSyllable]] = [:]
        for (romanization, originalIndex) in zip(romanizations, indices) {
            romanizationsByOriginal[originalIndex, default: []]
                .append(romanization)
        }
        return originals.enumerated().map { index, original in
            makeUnit(
                originalText: original.text,
                originalSyllables: [original],
                romanization: romanizationsByOriginal[index, default: []]
                    .map(\.text)
                    .joined()
            )
        }
    }

    private static func bestTimedMatch(
        for source: WatchLyricSyllable,
        in candidates: [WatchLyricSyllable]
    ) -> Int? {
        let match = candidates.indices.min {
            temporalDistance(source, candidates[$0])
                < temporalDistance(source, candidates[$1])
        }
        guard let match,
              temporalDistance(source, candidates[match])
                <= timingTolerance(for: source, and: candidates[match]) else {
            return nil
        }
        return match
    }

    private static func temporalDistance(
        _ lhs: WatchLyricSyllable,
        _ rhs: WatchLyricSyllable
    ) -> TimeInterval {
        let overlap = min(lhs.endTime, rhs.endTime)
            - max(lhs.startTime, rhs.startTime)
        if overlap >= 0 {
            let lhsMidpoint = (lhs.startTime + lhs.endTime) / 2
            let rhsMidpoint = (rhs.startTime + rhs.endTime) / 2
            return abs(lhsMidpoint - rhsMidpoint) * 0.15
        }
        return max(lhs.startTime, rhs.startTime)
            - min(lhs.endTime, rhs.endTime)
    }

    private static func timingTolerance(
        for lhs: WatchLyricSyllable,
        and rhs: WatchLyricSyllable
    ) -> TimeInterval {
        let longestDuration = max(
            lhs.endTime - lhs.startTime,
            rhs.endTime - rhs.startTime
        )
        return max(min(longestDuration * 0.75, 0.55), 0.18)
    }

    private static func segmentedUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        romanization: String
    ) -> [UnitDraft]? {
        let tokens = romanization
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return nil }

        if let punctuationAwareUnits = punctuationAwareUnits(
            originalText: originalText,
            originalSyllables: originalSyllables,
            romanization: romanization
        ) {
            return punctuationAwareUnits
        }

        let characters = Array(originalText)
        if let phoneticallyAlignedUnits = phoneticallyAlignedUnits(
            originalText: originalText,
            originalSyllables: originalSyllables,
            characters: characters,
            baseRanges: phoneticCharacterRanges(
                in: characters,
                range: characters.startIndex..<characters.endIndex
            ),
            annotations: tokens
        ) {
            return phoneticallyAlignedUnits
        }

        if originalSyllables.count == tokens.count,
           originalSyllables.map(\.text).joined() == originalText {
            return zip(originalSyllables, tokens).map {
                syllable,
                token in
                makeUnit(
                    originalText: syllable.text,
                    originalSyllables: [syllable],
                    romanization: token
                )
            }
        }

        if let phoneticRanges = phoneticCharacterRanges(
            in: originalText,
            matching: tokens
        ) {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: phoneticRanges,
                annotations: tokens
            )
        }

        let wordRanges = WatchLyricWordSegmenter.blockRanges(
            in: originalText
        )
        if wordRanges.count == tokens.count {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: wordRanges,
                annotations: tokens
            )
        }

        let characterRanges = annotationCharacterRanges(in: originalText)
        if characterRanges.count == tokens.count {
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: characterRanges,
                annotations: tokens
            )
        }

        return proportionallyAlignedUnits(
            originalText: originalText,
            originalSyllables: originalSyllables,
            annotations: tokens
        )
    }

    private static func punctuationAwareUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        romanization: String
    ) -> [UnitDraft]? {
        let characters = Array(originalText)
        let punctuationRanges = punctuationRanges(
            in: characters
        )
        let annotationSections = annotationSections(
            in: romanization
        )
        guard !punctuationRanges.isEmpty,
              punctuationRanges.count
                == annotationSections.punctuation.count,
              annotationSections.phoneticGroups.count
                == punctuationRanges.count + 1 else {
            return nil
        }

        var result: [UnitDraft] = []
        var phraseLowerBound = characters.startIndex
        for sectionIndex in
            annotationSections.phoneticGroups.indices {
            let phraseUpperBound =
                sectionIndex < punctuationRanges.count
                    ? punctuationRanges[sectionIndex].lowerBound
                    : characters.endIndex
            guard let phraseUnits = alignedPhraseUnits(
                originalText: originalText,
                originalSyllables: originalSyllables,
                characters: characters,
                range: phraseLowerBound..<phraseUpperBound,
                annotations:
                    annotationSections
                        .phoneticGroups[sectionIndex]
            ) else {
                return nil
            }
            result.append(contentsOf: phraseUnits)

            guard sectionIndex < punctuationRanges.count else {
                continue
            }
            let punctuationRange =
                punctuationRanges[sectionIndex]
            result.append(
                contentsOf: units(
                    originalText: originalText,
                    originalSyllables: originalSyllables,
                    ranges: [punctuationRange],
                    annotations: [
                        annotationSections
                            .punctuation[sectionIndex],
                    ]
                )
            )
            phraseLowerBound = punctuationRange.upperBound
        }
        return result
    }

    private static func alignedPhraseUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        characters: [Character],
        range: Range<Int>,
        annotations: [String]
    ) -> [UnitDraft]? {
        let baseRanges = phoneticCharacterRanges(
            in: characters,
            range: range
        )
        if baseRanges.isEmpty || annotations.isEmpty {
            return baseRanges.isEmpty && annotations.isEmpty
                ? []
                : nil
        }

        if let phoneticallyAlignedUnits = phoneticallyAlignedUnits(
            originalText: originalText,
            originalSyllables: originalSyllables,
            characters: characters,
            baseRanges: baseRanges,
            annotations: annotations
        ) {
            return phoneticallyAlignedUnits
        }

        let ranges: [Range<Int>]
        let alignedAnnotations: [String]
        if annotations.count == baseRanges.count {
            ranges = baseRanges
            alignedAnnotations = annotations
        } else if annotations.count < baseRanges.count {
            let groupedBaseRanges = partition(
                count: baseRanges.count,
                weights: annotations.map {
                    max(normalizedLatin($0).count, 1)
                }
            )
            ranges = groupedBaseRanges.map { groupedRange in
                let lowerBound = baseRanges[
                    groupedRange.lowerBound
                ].lowerBound
                let upperBound = baseRanges[
                    groupedRange.upperBound - 1
                ].upperBound
                return lowerBound..<upperBound
            }
            alignedAnnotations = annotations
        } else {
            let annotationRanges = partition(
                count: annotations.count,
                weights: baseRanges.map { baseRange in
                    String(
                        characters[baseRange]
                    ).contains(where: isCJKIdeograph)
                        ? 2
                        : 1
                }
            )
            ranges = baseRanges
            alignedAnnotations = annotationRanges.map {
                annotations[$0].joined(separator: " ")
            }
        }

        return units(
            originalText: originalText,
            originalSyllables: originalSyllables,
            ranges: ranges,
            annotations: alignedAnnotations
        )
    }

    private static func phoneticallyAlignedUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        characters: [Character],
        baseRanges: [Range<Int>],
        annotations: [String]
    ) -> [UnitDraft]? {
        guard !baseRanges.isEmpty, !annotations.isEmpty else {
            return nil
        }

        var result: [UnitDraft] = []
        var originalIndex = baseRanges.startIndex
        var annotationIndex = annotations.startIndex

        while originalIndex < baseRanges.endIndex,
              annotationIndex < annotations.endIndex {
            if let match = exactPhoneticMatch(
                characters: characters,
                baseRanges: baseRanges,
                originalIndex: originalIndex,
                annotations: annotations,
                annotationIndex: annotationIndex
            ) {
                let range = combinedRange(
                    in: baseRanges,
                    from: originalIndex,
                    count: match.originalCount
                )
                let annotationUpperBound =
                    annotationIndex + match.annotationCount
                let annotationRange =
                    annotationIndex..<annotationUpperBound
                result.append(
                    contentsOf: units(
                        originalText: originalText,
                        originalSyllables: originalSyllables,
                        ranges: [range],
                        annotations: [
                            annotations[annotationRange]
                                .joined(separator: " "),
                        ]
                    )
                )
                originalIndex += match.originalCount
                annotationIndex += match.annotationCount
                continue
            }

            guard isCJKRange(
                baseRanges[originalIndex],
                in: characters
            ) else {
                return nil
            }

            var cjkUpperBound = originalIndex + 1
            while cjkUpperBound < baseRanges.endIndex,
                  isCJKRange(
                      baseRanges[cjkUpperBound],
                      in: characters
                  ) {
                cjkUpperBound += 1
            }

            let annotationUpperBound: Int
            if cjkUpperBound == baseRanges.endIndex {
                annotationUpperBound = annotations.endIndex
            } else if let anchorIndex = nextAnnotationAnchor(
                characters: characters,
                baseRanges: baseRanges,
                originalIndex: cjkUpperBound,
                annotations: annotations,
                annotationIndex: annotationIndex
            ) {
                annotationUpperBound = anchorIndex
            } else {
                return nil
            }

            guard annotationUpperBound > annotationIndex,
                  let cjkUnits = cjkUnits(
                      originalText: originalText,
                      originalSyllables: originalSyllables,
                      baseRanges: Array(
                          baseRanges[
                              originalIndex..<cjkUpperBound
                          ]
                      ),
                      annotations: Array(
                          annotations[
                              annotationIndex..<annotationUpperBound
                          ]
                      )
                  ) else {
                return nil
            }
            result.append(contentsOf: cjkUnits)
            originalIndex = cjkUpperBound
            annotationIndex = annotationUpperBound
        }

        guard originalIndex == baseRanges.endIndex,
              annotationIndex == annotations.endIndex else {
            return nil
        }
        return result
    }

    private static func exactPhoneticMatch(
        characters: [Character],
        baseRanges: [Range<Int>],
        originalIndex: Int,
        annotations: [String],
        annotationIndex: Int
    ) -> PhoneticSequenceMatch? {
        let maximumOriginalCount = min(
            baseRanges.endIndex - originalIndex,
            24
        )
        let maximumAnnotationCount = min(
            annotations.endIndex - annotationIndex,
            8
        )
        guard maximumOriginalCount > 0,
              maximumAnnotationCount > 0 else {
            return nil
        }

        for originalCount in 1...maximumOriginalCount {
            let range = combinedRange(
                in: baseRanges,
                from: originalIndex,
                count: originalCount
            )
            guard !String(
                characters[range]
            ).contains(where: isCJKIdeograph) else {
                break
            }

            let source = String(characters[range])
            for annotationCount in 1...maximumAnnotationCount {
                let annotationUpperBound =
                    annotationIndex + annotationCount
                let annotation = annotations[
                    annotationIndex..<annotationUpperBound
                ].joined()
                if romanizationMatches(
                    source: source,
                    annotation: annotation
                ) {
                    return PhoneticSequenceMatch(
                        originalCount: originalCount,
                        annotationCount: annotationCount
                    )
                }
            }
        }
        return nil
    }

    private static func nextAnnotationAnchor(
        characters: [Character],
        baseRanges: [Range<Int>],
        originalIndex: Int,
        annotations: [String],
        annotationIndex: Int
    ) -> Int? {
        guard originalIndex < baseRanges.endIndex else {
            return annotations.endIndex
        }

        for candidateIndex in annotationIndex..<annotations.endIndex {
            if exactPhoneticMatch(
                characters: characters,
                baseRanges: baseRanges,
                originalIndex: originalIndex,
                annotations: annotations,
                annotationIndex: candidateIndex
            ) != nil {
                return candidateIndex
            }
        }
        return nil
    }

    private static func cjkUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        baseRanges: [Range<Int>],
        annotations: [String]
    ) -> [UnitDraft]? {
        guard !baseRanges.isEmpty, !annotations.isEmpty else {
            return nil
        }

        var chunks: [[String]] = []
        for annotation in annotations {
            if isReadingContinuation(annotation),
               !chunks.isEmpty {
                chunks[chunks.count - 1].append(annotation)
            } else {
                chunks.append([annotation])
            }
        }

        let ranges: [Range<Int>]
        let groupedAnnotations: [String]
        if chunks.count >= baseRanges.count {
            ranges = baseRanges
            groupedAnnotations = baseRanges.indices.map { index in
                let selectedChunks = index == baseRanges.count - 1
                    ? chunks[index...]
                    : chunks[index...index]
                return selectedChunks
                    .flatMap { $0 }
                    .joined(separator: " ")
            }
        } else {
            let groupedBaseRanges = partition(
                count: baseRanges.count,
                weights: chunks.map { chunk in
                    max(
                        normalizedLatin(chunk.joined()).count,
                        1
                    )
                }
            )
            ranges = groupedBaseRanges.map { groupedRange in
                let lowerBound = baseRanges[
                    groupedRange.lowerBound
                ].lowerBound
                let upperBound = baseRanges[
                    groupedRange.upperBound - 1
                ].upperBound
                return lowerBound..<upperBound
            }
            groupedAnnotations = chunks.map {
                $0.joined(separator: " ")
            }
        }

        return units(
            originalText: originalText,
            originalSyllables: originalSyllables,
            ranges: ranges,
            annotations: groupedAnnotations
        )
    }

    private static func combinedRange(
        in ranges: [Range<Int>],
        from index: Int,
        count: Int
    ) -> Range<Int> {
        let lowerBound = ranges[index].lowerBound
        let upperBound = ranges[
            index + count - 1
        ].upperBound
        return lowerBound..<upperBound
    }

    private static func isCJKRange(
        _ range: Range<Int>,
        in characters: [Character]
    ) -> Bool {
        String(characters[range]).contains(
            where: isCJKIdeograph
        )
    }

    private static func isReadingContinuation(
        _ annotation: String
    ) -> Bool {
        switch normalizedLatin(annotation) {
        case "a", "i", "u", "e", "o", "n":
            true
        default:
            false
        }
    }

    private static func romanizationMatches(
        source: String,
        annotation: String
    ) -> Bool {
        let annotation = normalizedLatin(annotation)
        guard !annotation.isEmpty else { return false }
        let transformed = source.applyingTransform(
            .toLatin,
            reverse: false
        ) ?? source
        return normalizedTransliterationVariants(
            transformed
        ).contains(annotation)
    }

    private static func normalizedTransliterationVariants(
        _ text: String
    ) -> Set<String> {
        let text = text.lowercased()
            .replacingOccurrences(of: "ā", with: "aa")
            .replacingOccurrences(of: "ē", with: "ee")
            .replacingOccurrences(of: "ī", with: "ii")
            .replacingOccurrences(of: "ū", with: "uu")
        return [
            text.replacingOccurrences(of: "ō", with: "ou"),
            text.replacingOccurrences(of: "ō", with: "oo"),
        ].reduce(into: Set<String>()) { result, variant in
            result.insert(normalizedLatin(variant))
        }
    }

    private static func punctuationRanges(
        in characters: [Character]
    ) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var index = characters.startIndex
        while index < characters.endIndex {
            guard isAnnotationPunctuation(characters[index]) else {
                index += 1
                continue
            }

            let lowerBound = index
            index += 1
            while index < characters.endIndex,
                  !isPhoneticCharacter(characters[index]) {
                index += 1
            }
            result.append(lowerBound..<index)
        }
        return result
    }

    private static func phoneticCharacterRanges(
        in characters: [Character],
        range: Range<Int>
    ) -> [Range<Int>] {
        let indices = range.filter {
            isPhoneticCharacter(characters[$0])
        }
        return indices.enumerated().map { offset, index in
            let lowerBound = offset == 0
                ? range.lowerBound
                : index
            let upperBound = offset + 1 < indices.count
                ? indices[offset + 1]
                : range.upperBound
            return lowerBound..<upperBound
        }
    }

    private static func annotationSections(
        in romanization: String
    ) -> AnnotationSections {
        var phoneticGroups: [[String]] = [[]]
        var punctuation: [String] = []
        var phoneticBuffer = ""
        var punctuationBuffer = ""

        func flushPhoneticBuffer() {
            guard !phoneticBuffer.isEmpty else { return }
            phoneticGroups[phoneticGroups.count - 1]
                .append(phoneticBuffer)
            phoneticBuffer = ""
        }

        func flushPunctuationBuffer() {
            guard !punctuationBuffer.isEmpty else { return }
            punctuation.append(punctuationBuffer)
            phoneticGroups.append([])
            punctuationBuffer = ""
        }

        for character in romanization {
            if character.isWhitespace {
                flushPhoneticBuffer()
            } else if isPhoneticCharacter(character) {
                flushPunctuationBuffer()
                phoneticBuffer.append(character)
            } else {
                flushPhoneticBuffer()
                punctuationBuffer.append(character)
            }
        }
        flushPhoneticBuffer()
        flushPunctuationBuffer()

        return AnnotationSections(
            phoneticGroups: phoneticGroups,
            punctuation: punctuation
        )
    }

    private static func isPhoneticCharacter(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    private static func isAnnotationPunctuation(
        _ character: Character
    ) -> Bool {
        !character.isWhitespace
            && !isPhoneticCharacter(character)
    }

    private static func phoneticCharacterRanges(
        in text: String,
        matching annotations: [String]
    ) -> [Range<Int>]? {
        let characters = Array(text)
        guard !characters.isEmpty,
              annotations.count <= characters.count else {
            return nil
        }

        var successfulMatches: [
            PhoneticMatchState: [Range<Int>]
        ] = [:]
        var failedMatches: Set<PhoneticMatchState> = []

        func match(
            characterOffset: Int,
            annotationOffset: Int
        ) -> [Range<Int>]? {
            let state = PhoneticMatchState(
                characterOffset: characterOffset,
                annotationOffset: annotationOffset
            )
            if let cached = successfulMatches[state] {
                return cached
            }
            guard !failedMatches.contains(state) else { return nil }
            guard annotationOffset < annotations.count else {
                let result: [Range<Int>]? =
                    characterOffset == characters.count ? [] : nil
                if let result {
                    successfulMatches[state] = result
                } else {
                    failedMatches.insert(state)
                }
                return result
            }

            let remainingAnnotations =
                annotations.count - annotationOffset - 1
            let maximumUpperBound =
                characters.count - remainingAnnotations
            guard characterOffset < maximumUpperBound else {
                failedMatches.insert(state)
                return nil
            }

            let annotation = normalizedLatin(
                annotations[annotationOffset]
            )
            for upperBound in
                (characterOffset + 1)...maximumUpperBound {
                let source = String(
                    characters[characterOffset..<upperBound]
                )
                let transformed = source.applyingTransform(
                    .toLatin,
                    reverse: false
                ) ?? source
                guard normalizedLatin(transformed) == annotation else {
                    continue
                }

                if let suffix = match(
                    characterOffset: upperBound,
                    annotationOffset: annotationOffset + 1
                ) {
                    let result =
                        [characterOffset..<upperBound] + suffix
                    successfulMatches[state] = result
                    return result
                }
            }

            failedMatches.insert(state)
            return nil
        }

        return match(characterOffset: 0, annotationOffset: 0)
    }

    private static func proportionallyAlignedUnits(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        annotations: [String]
    ) -> [UnitDraft] {
        let characters = Array(originalText)
        let baseRanges = annotationCharacterRanges(in: originalText)
        guard !characters.isEmpty, !baseRanges.isEmpty else {
            return []
        }

        if annotations.count <= baseRanges.count {
            let weights = annotations.map {
                max(normalizedLatin($0).count, 1)
            }
            return units(
                originalText: originalText,
                originalSyllables: originalSyllables,
                ranges: partition(
                    count: characters.count,
                    weights: weights
                ),
                annotations: annotations
            )
        }

        let weights = baseRanges.map { range in
            String(characters[range]).contains(where: isCJKIdeograph)
                ? 2
                : 1
        }
        let annotationRanges = partition(
            count: annotations.count,
            weights: weights
        )
        return units(
            originalText: originalText,
            originalSyllables: originalSyllables,
            ranges: baseRanges,
            annotations: annotationRanges.map {
                annotations[$0].joined(separator: " ")
            }
        )
    }

    private static func partition(
        count: Int,
        weights: [Int]
    ) -> [Range<Int>] {
        guard count > 0, !weights.isEmpty else { return [] }
        let totalWeight = max(weights.reduce(0, +), 1)
        var result: [Range<Int>] = []
        var lowerBound = 0
        var cumulativeWeight = 0

        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            let remainingGroups = weights.count - index - 1
            let idealUpperBound = Int(
                (Double(count) * Double(cumulativeWeight)
                    / Double(totalWeight)).rounded()
            )
            let upperBound = index == weights.count - 1
                ? count
                : min(
                    max(idealUpperBound, lowerBound + 1),
                    count - remainingGroups
                )
            result.append(lowerBound..<upperBound)
            lowerBound = upperBound
        }
        return result
    }

    private static func units(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        ranges: [Range<Int>],
        annotations: [String]
    ) -> [UnitDraft] {
        let characters = Array(originalText)
        let timedCharacters = characterSyllables(
            for: originalText,
            from: originalSyllables
        )
        return zip(ranges, annotations).map { range, annotation in
            makeUnit(
                originalText: String(characters[range]),
                originalSyllables:
                    timedCharacters.map { Array($0[range]) } ?? [],
                romanization: annotation
            )
        }
    }

    private static func annotationCharacterRanges(
        in text: String
    ) -> [Range<Int>] {
        let characters = Array(text)
        let annotatedIndices = characters.indices.filter {
            !characters[$0].isWhitespace
        }
        return annotatedIndices.enumerated().map { offset, index in
            let lowerBound = offset == 0 ? characters.startIndex : index
            let upperBound = offset + 1 < annotatedIndices.count
                ? annotatedIndices[offset + 1]
                : characters.endIndex
            return lowerBound..<upperBound
        }
    }

    private static func characterSyllables(
        for text: String,
        from syllables: [WatchLyricSyllable]
    ) -> [WatchLyricSyllable]? {
        guard !syllables.isEmpty,
              syllables.map(\.text).joined() == text else {
            return nil
        }

        return syllables.flatMap {
            syllable -> [WatchLyricSyllable] in
            let characters = Array(syllable.text)
            guard !characters.isEmpty else { return [] }
            let duration = max(
                syllable.endTime - syllable.startTime,
                0
            )
            let characterDuration = duration / Double(characters.count)
            return characters.enumerated().map { offset, character in
                let startTime = syllable.startTime
                    + Double(offset) * characterDuration
                let endTime = offset == characters.count - 1
                    ? syllable.endTime
                    : startTime + characterDuration
                return WatchLyricSyllable(
                    text: String(character),
                    startTime: startTime,
                    endTime: max(endTime, startTime)
                )
            }
        }
    }

    private static func makeUnit(
        originalText: String,
        originalSyllables: [WatchLyricSyllable],
        romanization: String?
    ) -> UnitDraft {
        let romanization = normalized(romanization) ?? ""
        let romanizationSyllables: [WatchLyricSyllable]
        if !romanization.isEmpty,
           let first = originalSyllables.first,
           let last = originalSyllables.last {
            romanizationSyllables = [
                WatchLyricSyllable(
                    text: romanization,
                    startTime: first.startTime,
                    endTime: max(last.endTime, first.startTime)
                ),
            ]
        } else {
            romanizationSyllables = []
        }
        return UnitDraft(
            originalText: originalText,
            originalSyllables: originalSyllables,
            romanizationText: romanization,
            romanizationSyllables: romanizationSyllables
        )
    }

    private static func normalized(_ text: String?) -> String? {
        let text = text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private static func normalizedLatin(_ text: String) -> String {
        text
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive,
                ],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func isCJKIdeograph(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2FA1F:
                true
            default:
                false
            }
        }
    }

    private static func insert(
        _ units: [WatchLyricRubyUnit],
        for key: CacheKey
    ) {
        guard cache[key] == nil else { return }
        cache[key] = units
        insertionOrder.append(key)
        if insertionOrder.count > cacheCapacity {
            cache.removeValue(forKey: insertionOrder.removeFirst())
        }
    }
}

private extension WatchLyricRomanizationAligner {
    struct UnitDraft {
        let originalText: String
        let originalSyllables: [WatchLyricSyllable]
        let romanizationText: String
        let romanizationSyllables: [WatchLyricSyllable]
    }

    struct PhoneticMatchState: Hashable {
        let characterOffset: Int
        let annotationOffset: Int
    }

    struct PhoneticSequenceMatch {
        let originalCount: Int
        let annotationCount: Int
    }

    struct AnnotationSections {
        let phoneticGroups: [[String]]
        let punctuation: [String]
    }

    struct CacheKey: Hashable {
        let originalText: String
        let romanization: String
        let originalSyllables: [WatchLyricSyllable]
        let romanizationSyllables: [WatchLyricSyllable]
    }
}
