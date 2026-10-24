import Foundation

struct LyricsSelectionManager {
    static let defaultCharacterLimit = 150

    enum TapResult: Equatable {
        case changed
        case requiresReplacement(index: Int)
        case ignored
    }

    enum RowState: Equatable {
        case selected(SelectionPosition)
        case selectable
        case replaceable
        case disabled
    }

    enum SelectionPosition: Equatable {
        case single
        case first
        case middle
        case last
    }

    let lyrics: [LyricLine]
    let characterLimit: Int
    private(set) var selectedRange: ClosedRange<Int>?

    init(
        lyrics: [LyricLine],
        initialLyricID: LyricLine.ID,
        characterLimit: Int = Self.defaultCharacterLimit
    ) {
        self.lyrics = lyrics
        self.characterLimit = max(characterLimit, 1)

        if let index = lyrics.firstIndex(where: {
            $0.id == initialLyricID
        }), lyrics[index].text.count <= self.characterLimit {
            selectedRange = index...index
        } else {
            selectedRange = nil
        }
    }

    var selectedLyrics: [LyricLine] {
        guard let selectedRange else { return [] }
        return Array(lyrics[selectedRange])
    }

    var selectedLineCount: Int {
        guard let selectedRange else { return 0 }
        return selectedRange.upperBound - selectedRange.lowerBound + 1
    }

    var selectedCharacterCount: Int {
        guard let selectedRange else { return 0 }
        return characterCount(in: selectedRange)
    }

    var canShare: Bool {
        selectedRange != nil
    }

    mutating func tapLyric(at index: Int) -> TapResult {
        guard lyrics.indices.contains(index),
              lyrics[index].text.count <= characterLimit else {
            return .ignored
        }

        guard let selectedRange else {
            self.selectedRange = index...index
            return .changed
        }

        if selectedRange.contains(index) {
            if selectedRange.lowerBound == selectedRange.upperBound {
                self.selectedRange = nil
            } else {
                self.selectedRange = index...index
            }
            return .changed
        }

        let proposedRange = rangeExtendingSelection(to: index)
        guard characterCount(in: proposedRange) <= characterLimit else {
            return .requiresReplacement(index: index)
        }

        self.selectedRange = proposedRange
        return .changed
    }

    mutating func replaceSelection(with index: Int) {
        guard lyrics.indices.contains(index),
              lyrics[index].text.count <= characterLimit else {
            return
        }
        selectedRange = index...index
    }

    func rowState(at index: Int) -> RowState {
        guard lyrics.indices.contains(index),
              lyrics[index].text.count <= characterLimit else {
            return .disabled
        }

        guard let selectedRange else { return .selectable }
        if selectedRange.contains(index) {
            return .selected(
                selectionPosition(
                    for: index,
                    in: selectedRange
                )
            )
        }

        let proposedRange = rangeExtendingSelection(to: index)
        return characterCount(in: proposedRange) <= characterLimit
            ? .selectable
            : .replaceable
    }

    private func rangeExtendingSelection(
        to index: Int
    ) -> ClosedRange<Int> {
        guard let selectedRange else { return index...index }
        if index < selectedRange.lowerBound {
            return index...selectedRange.upperBound
        }
        return selectedRange.lowerBound...index
    }

    private func characterCount(
        in range: ClosedRange<Int>
    ) -> Int {
        lyrics[range].reduce(into: 0) { count, lyric in
            count += lyric.text.count
        }
    }

    private func selectionPosition(
        for index: Int,
        in range: ClosedRange<Int>
    ) -> SelectionPosition {
        if range.lowerBound == range.upperBound { return .single }
        if index == range.lowerBound { return .first }
        if index == range.upperBound { return .last }
        return .middle
    }
}
