import SwiftUI

struct ConnectionUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("ui.error.music_content_load_failed", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("ui.common.retry", action: retry)
        }
    }
}
