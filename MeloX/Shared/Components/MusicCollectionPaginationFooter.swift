import SwiftUI

struct MusicCollectionPaginationFooter: View {
    let isLoading: Bool
    let failureMessage: String?
    let loadToken: Int
    var loadingTitle = L10n.string("ui.common.loading_more_songs")
    let action: () async -> Void

    var body: some View {
        Group {
            if let failureMessage {
                VStack(spacing: 8) {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("ui.common.reload") {
                        Task {
                            await action()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(loadingTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .task(id: loadToken) {
                    guard !isLoading else { return }
                    await action()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
