import SwiftUI

struct NeteaseShareSheet: View {
    let presentation: NeteaseSharePresentation

    var body: some View {
        NavigationStack {
            switch presentation.mode {
            case .privateMessage:
                NeteasePrivateMessageView(resource: presentation.resource)
            case .timeline:
                NeteaseTimelineShareView(resource: presentation.resource)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct NeteaseShareResourcePreview: View {
    let resource: NeteaseShareResource

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: resource.artworkURL, cornerRadius: 8)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.headline)
                    .lineLimit(2)

                if let subtitle = resource.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(resource.kindTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NeteaseTimelineShareView: View {
    let resource: NeteaseShareResource

    @Environment(\.dismiss) private var dismiss
    @Environment(NeteaseAPI.self) private var api

    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("ui.sharing.forwarded_content") {
                NeteaseShareResourcePreview(resource: resource)
            }

            Section("ui.sharing.say_something") {
                TextField(
                    "ui.common.optional",
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(3...8)
            }
        }
        .navigationTitle("ui.sharing.forward_to_feed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("ui.common.cancel") {
                    dismiss()
                }
                .disabled(isSending)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await share() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("ui.common.publish")
                    }
                }
                .disabled(isSending)
            }
        }
        .interactiveDismissDisabled(isSending)
        .alert(
            "ui.sharing.forward_failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.string("ui.error.netease_operation_incomplete"))
        }
    }

    private func share() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            try await api.shareToTimeline(
                resource,
                message: message.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
