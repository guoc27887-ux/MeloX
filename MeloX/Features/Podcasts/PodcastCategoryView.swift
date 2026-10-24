import SwiftUI

struct PodcastCategoryView: View {
    let category: PodcastCategory

    @Environment(NeteaseAPI.self) private var api

    @State private var podcasts: [Podcast] = []
    @State private var phase: LoadingPhase = .loading
    @State private var hasMore = false
    @State private var totalCount: Int?
    @State private var isLoadingMore = false
    @State private var loadMoreError: String?
    @State private var reloadToken = 0

    private let pageSize = 30

    var body: some View {
        Group {
            if podcasts.isEmpty {
                initialState
            } else {
                podcastList
            }
        }
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.large)
        .task(id: reloadToken) {
            guard podcasts.isEmpty else { return }
            await load(reset: true)
        }
    }

    @ViewBuilder
    private var initialState: some View {
        switch phase {
        case .loading:
            ProgressView(L10n.format("ui.podcasts.loading_category", category.localizedName))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ConnectionUnavailableView(message: message) {
                reloadToken += 1
            }
        case .loaded:
            ContentUnavailableView(
                "ui.podcasts.empty",
                systemImage: "mic"
            )
        }
    }

    private var podcastList: some View {
        List {
            if let totalCount, totalCount > 0 {
                Text(L10n.format("ui.podcasts.count", totalCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }

            ForEach(podcasts) { podcast in
                NavigationLink(
                    value: MusicRoute.podcast(podcast)
                ) {
                    PodcastListRow(podcast: podcast)
                }
            }

            if hasMore {
                paginationFooter
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await load(reset: true)
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if let loadMoreError {
            VStack(spacing: 8) {
                Text(loadMoreError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("ui.common.reload") {
                    Task { await loadMore() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text("ui.podcasts.loading_more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .task(id: podcasts.count) {
                await loadMore()
            }
        }
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            loadMoreError = nil
        }

        do {
            let page = try await api.podcasts(
                categoryID: category.id,
                offset: reset ? 0 : podcasts.count,
                limit: pageSize
            )
            try Task.checkCancellation()

            if reset {
                podcasts = page.podcasts
            } else {
                appendUnique(page.podcasts)
            }
            hasMore = page.hasMore
            totalCount = page.totalCount
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            if reset {
                phase = .failed(error.localizedDescription)
            } else {
                loadMoreError = error.localizedDescription
            }
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        await load(reset: false)
    }

    private func appendUnique(_ newPodcasts: [Podcast]) {
        var identifiers = Set(podcasts.map(\.id))
        podcasts.append(
            contentsOf: newPodcasts.filter {
                identifiers.insert($0.id).inserted
            }
        )
    }
}
