import SwiftUI

struct DesktopPlayerInspector: View {
    let kind: DesktopInspector
    var isActive = true

    var body: some View {
        Group {
            switch kind {
            case .lyrics:
                DesktopPlaybackPositionedLyricsView(
                    compact: true,
                    allowsLyricBlur: false,
                    isActive: isActive
                )
            case .queue:
                DesktopQueueView(presentation: .inspector)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
