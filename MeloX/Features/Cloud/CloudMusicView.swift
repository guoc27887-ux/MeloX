import SwiftUI
import UniformTypeIdentifiers

struct CloudMusicView: View {
    let searchQuery: String

    @Environment(CloudMusicStore.self) private var cloud
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var showsFileImporter = false
    @State private var pendingDeletion: CloudSong?
    @State private var searchReloadToken = 0
    @State private var searchPreparationID: UUID?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsFileImporter = true
                    } label: {
                        if cloud.isUploading {
                            ProgressView()
                        } else {
                            Label("ui.cloud.upload_music", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(cloud.isUploading)
                    .accessibilityLabel(
                        cloud.isUploading
                            ? L10n.string("ui.cloud.uploading_music")
                            : L10n.string("ui.cloud.upload_music")
                    )
                }
            }
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await cloud.upload(fileAt: url) }
                case .failure(let error):
                    cloud.reportImportError(error)
                }
            }
            .confirmationDialog(
                "ui.cloud.delete.confirmation",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeletion = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { item in
                Button(
                    L10n.format("ui.cloud.delete_named", item.songName),
                    role: .destructive
                ) {
                    Task { await cloud.delete(item) }
                }
                Button("ui.common.cancel", role: .cancel) {}
            } message: { _ in
                Text("ui.cloud.delete.message")
            }
            .alert(
                "ui.cloud.error.title",
                isPresented: Binding(
                    get: { cloud.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { cloud.clearError() }
                    }
                )
            ) {
                Button("ui.common.ok", role: .cancel) {
                    cloud.clearError()
                }
            } message: {
                Text(cloud.errorMessage ?? L10n.string("ui.common.unknown_error"))
            }
            .task(id: settings.cookie) {
                await cloud.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch cloud.phase {
        case .loading where cloud.items.isEmpty:
            ProgressView("ui.cloud.loading")
        case .failed(let message) where cloud.items.isEmpty:
            ConnectionUnavailableView(message: message) {
                Task { await cloud.refresh(force: true) }
            }
        default:
            cloudList
        }
    }

    private var cloudList: some View {
        List {
            if cloud.isUploading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("ui.cloud.uploading_foreground")
                        .foregroundStyle(.secondary)
                }
            }

            if !displayedItems.isEmpty {
                Section {
                    Button {
                        Task { await player.playAll(displayedSongs) }
                    } label: {
                        Label(
                            isSearching
                                ? L10n.string("ui.common.play_search_results")
                                : L10n.string("ui.common.play_all"),
                            systemImage: "play.fill"
                        )
                    }
                } header: {
                    if isSearching {
                        Text(L10n.format("ui.common.search_result_count", displayedItems.count))
                    } else if let quota = cloud.quotaDescription {
                        Text(quota)
                    } else {
                        Text(L10n.format("ui.cloud.total_song_count", cloud.totalCount))
                    }
                }
            }

            ForEach(displayedItems) { item in
                Button {
                    Task {
                        await player.play(
                            item.simpleSong,
                            in: displayedSongs
                        )
                    }
                } label: {
                    TrackRowView(song: item.simpleSong, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .disabled(cloud.isDeleting(item))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDeletion = item
                    } label: {
                        Label("ui.cloud.delete", systemImage: "trash")
                    }
                }
                .task {
                    await cloud.loadMoreIfNeeded(after: item)
                }
            }

            paginationFooter
        }
        .listStyle(.plain)
        .refreshable {
            await cloud.refresh(force: true)
            if isSearching {
                await prepareSearchResults(debounced: false)
            }
        }
        .overlay {
            if displayedItems.isEmpty,
               !cloud.isUploading,
               !isPreparingSearchResults,
               !hasSearchLoadFailure {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else {
                    ContentUnavailableView {
                        Label(
                            "ui.cloud.empty",
                            systemImage: "externaldrive"
                        )
                    } description: {
                        Text(
                            "ui.cloud.empty.message"
                        )
                    } actions: {
                        Button("ui.cloud.upload_music") {
                            showsFileImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task(
            id: CloudMusicSearchRequest(
                query: normalizedSearchQuery,
                reloadToken: searchReloadToken
            )
        ) {
            await prepareSearchResults(debounced: true)
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var displayedItems: [CloudSong] {
        filterCloudSongs(cloud.items, query: normalizedSearchQuery)
    }

    private var displayedSongs: [Song] {
        displayedItems.map(\.simpleSong)
    }

    private var isPreparingSearchResults: Bool {
        searchPreparationID != nil
    }

    private var hasSearchLoadFailure: Bool {
        isSearching && cloud.loadMoreError != nil && cloud.hasMore
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isSearching, isPreparingSearchResults {
            HStack(spacing: 8) {
                ProgressView()
                Text("ui.cloud.searching_all")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        } else if let failureMessage = cloud.loadMoreError,
                  cloud.hasMore {
            VStack(spacing: 8) {
                Text(failureMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(
                    isSearching
                        ? L10n.string("ui.library.search_again")
                        : L10n.string("ui.common.reload")
                ) {
                    if isSearching {
                        searchReloadToken += 1
                    } else {
                        Task { await cloud.loadMore() }
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        } else if !isSearching, cloud.isLoadingMore {
            HStack {
                Spacer()
                ProgressView("ui.common.loading_more")
                Spacer()
            }
        }
    }

    private func prepareSearchResults(debounced: Bool) async {
        guard isSearching else {
            searchPreparationID = nil
            return
        }

        guard cloud.hasMore else { return }

        let preparationID = UUID()
        searchPreparationID = preparationID
        defer {
            if searchPreparationID == preparationID {
                searchPreparationID = nil
            }
        }

        if debounced {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        await cloud.loadRemaining()
    }
}

private struct CloudMusicSearchRequest: Hashable {
    let query: String
    let reloadToken: Int
}
