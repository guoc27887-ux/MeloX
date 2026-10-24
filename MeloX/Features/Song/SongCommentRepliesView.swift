import SwiftUI

struct SongCommentRepliesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let songID: Int
    let parentComment: SongComment

    var body: some View {
        NavigationStack {
            SongCommentRepliesView(songID: songID, parentComment: parentComment)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("ui.comments.close_replies")
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

struct SongCommentRepliesView: View {
    @Environment(NeteaseAPI.self) private var api

    let songID: Int
    let parentComment: SongComment

    @State private var ownerComment: SongComment?
    @State private var replies: [SongComment] = []
    @State private var totalCount = 0
    @State private var phase: LoadingPhase = .loading
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var reloadToken = 0

    var body: some View {
        List {
            Section("ui.comments.original") {
                SongCommentRow(comment: ownerComment ?? parentComment)
            }

            Section {
                repliesContent

                if hasMore || paginationError != nil {
                    loadMoreRow
                }
            } header: {
                Text(
                    totalCount > 0
                        ? L10n.format("ui.comments.all_replies_count", totalCount)
                        : L10n.string("ui.comments.all_replies")
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.comments.replies.title")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReplies()
        }
        .task(id: reloadToken) {
            await loadReplies()
        }
    }

    @ViewBuilder
    private var repliesContent: some View {
        switch phase {
        case .loading where replies.isEmpty:
            HStack {
                Spacer()
                ProgressView("ui.comments.replies.loading")
                Spacer()
            }
        case .failed(let message) where replies.isEmpty:
            VStack(spacing: 12) {
                Label("ui.comments.replies.load_failed", systemImage: "exclamationmark.bubble")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("ui.common.retry") {
                    reloadToken += 1
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        default:
            if replies.isEmpty {
                ContentUnavailableView("ui.comments.replies.empty", systemImage: "bubble.left")
            } else {
                ForEach(replies) { reply in
                    SongCommentRow(comment: reply)
                }
            }
        }
    }

    private var loadMoreRow: some View {
        Group {
            if let paginationError {
                Button {
                    Task { await loadMoreReplies() }
                } label: {
                    VStack(spacing: 4) {
                        Text("ui.comments.replies.reload_more")
                        Text(paginationError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView("ui.comments.replies.loading_more")
                    Spacer()
                }
                .task {
                    await loadMoreReplies()
                }
            }
        }
    }

    private func loadReplies() async {
        phase = .loading
        paginationError = nil

        do {
            let response = try await api.songCommentReplies(
                songID: songID,
                parentCommentID: parentComment.id
            )
            try Task.checkCancellation()
            ownerComment = response.data.ownerComment
            replies = response.data.comments
            totalCount = response.data.totalCount
            hasMore = response.data.hasMore && !response.data.comments.isEmpty
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMoreReplies() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        paginationError = nil
        defer { isLoadingMore = false }

        do {
            let response = try await api.songCommentReplies(
                songID: songID,
                parentCommentID: parentComment.id,
                time: Int64(replies.last?.time ?? -1)
            )
            try Task.checkCancellation()
            let loadedIDs = Set(replies.map(\.id))
            let newReplies = response.data.comments.filter { !loadedIDs.contains($0.id) }
            replies.append(contentsOf: newReplies)
            totalCount = response.data.totalCount
            hasMore = response.data.hasMore && !newReplies.isEmpty
        } catch is CancellationError {
            return
        } catch {
            paginationError = error.localizedDescription
        }
    }
}
