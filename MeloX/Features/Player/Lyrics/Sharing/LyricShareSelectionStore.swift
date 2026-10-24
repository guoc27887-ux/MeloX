import Observation
import UIKit

@MainActor
@Observable
final class LyricShareSelectionStore {
    let presentation: LyricSharePresentation
    private(set) var selection: LyricsSelectionManager
    var artwork: UIImage?

    init(presentation: LyricSharePresentation) {
        self.presentation = presentation
        selection = LyricsSelectionManager(
            lyrics: presentation.lyrics,
            initialLyricID: presentation.initialLyricID
        )
    }

    var selectedLyrics: [LyricLine] {
        selection.selectedLyrics
    }

    var selectedLineCount: Int {
        selection.selectedLineCount
    }

    var selectedCharacterCount: Int {
        selection.selectedCharacterCount
    }

    var characterLimit: Int {
        selection.characterLimit
    }

    var canShare: Bool {
        selection.canShare
    }

    var payload: LyricSharePayload? {
        guard canShare else { return nil }
        return LyricSharePayload(
            song: presentation.song,
            lyrics: selectedLyrics
        )
    }

    func rowState(
        at index: Int
    ) -> LyricsSelectionManager.RowState {
        selection.rowState(at: index)
    }

    @discardableResult
    func tapLyric(
        at index: Int
    ) -> LyricsSelectionManager.TapResult {
        var updatedSelection = selection
        let result = updatedSelection.tapLyric(at: index)
        selection = updatedSelection
        return result
    }

    func replaceSelection(with index: Int) {
        var updatedSelection = selection
        updatedSelection.replaceSelection(with: index)
        selection = updatedSelection
    }
}
