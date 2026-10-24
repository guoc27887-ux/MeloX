import SwiftUI
import UIKit

struct LyricsShareSheet: View {
    let payload: LyricSharePayload
    let artwork: UIImage?
    let onComplete: (Bool) -> Void

    var body: some View {
        SystemShareSheet(
            activityItems: activityItems,
            onComplete: onComplete
        )
    }

    private var activityItems: [Any] {
        [
            LyricShareURLActivityItemSource(
                payload: payload,
                artwork: artwork
            ),
            LyricShareTextActivityItemSource(payload: payload),
        ]
    }
}
