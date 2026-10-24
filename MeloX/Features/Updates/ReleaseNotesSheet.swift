import SwiftUI

struct ReleaseNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let releaseNotes: AppReleaseNotes

    var body: some View {
        NavigationStack {
            ReleaseNotesView(
                releaseNotes: releaseNotes,
                currentVersion: releaseNotes.version
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ui.release_notes.start") {
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
