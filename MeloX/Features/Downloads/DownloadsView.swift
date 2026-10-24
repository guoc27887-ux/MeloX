import SwiftUI

struct DownloadsView: View {
    @Environment(DownloadStore.self) private var downloads
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var showsClearConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                Toggle(
                    "ui.downloads.automatic_cache",
                    isOn: $settings.automaticallyCachesFrequentlyPlayedSongs
                )

                if settings.automaticallyCachesFrequentlyPlayedSongs {
                    Picker(
                        "ui.downloads.trigger_count",
                        selection: $settings.automaticCachePlaybackThreshold
                    ) {
                        ForEach(AppSettings.automaticCachePlaybackThresholdOptions, id: \.self) { count in
                            Text(L10n.format("ui.common.times", count)).tag(count)
                        }
                    }

                    Picker("ui.downloads.automatic_cache_quality", selection: $settings.automaticCacheQuality) {
                        ForEach(MusicQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                }
            } header: {
                Text("ui.downloads.section.automatic_cache")
            } footer: {
                Text("ui.downloads.automatic_cache.footer")
            }

            if !activeDownloads.isEmpty {
                Section("ui.downloads.active") {
                    ForEach(activeDownloads) { download in
                        VStack(alignment: .leading, spacing: 8) {
                            TrackRowView(song: download.song, showsArtwork: true)

                            if let fractionCompleted = download.fractionCompleted {
                                ProgressView(value: fractionCompleted)
                                    .progressViewStyle(.linear)
                                    .accessibilityValue(
                                        fractionCompleted.formatted(
                                            .percent
                                                .precision(.fractionLength(0))
                                                .locale(L10n.locale)
                                        )
                                    )
                            }

                            HStack {
                                Text(download.quality.title)
                                Spacer()
                                Text(progressText(for: download))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                downloads.cancel(songID: download.id)
                            } label: {
                                Label("ui.common.cancel", systemImage: "xmark")
                            }
                        }
                    }
                }
            }

            if !downloads.downloads.isEmpty {
                Section {
                    Button {
                        Task { await player.playAll(downloads.downloadedSongs) }
                    } label: {
                        Label("ui.common.play_all", systemImage: "play.fill")
                    }

                    ForEach(downloads.downloads) { download in
                        Button {
                            Task {
                                await player.play(
                                    download.song,
                                    in: downloads.downloadedSongs
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                TrackRowView(song: download.song, showsArtwork: true)
                                HStack {
                                    Text(download.quality.title)
                                    Spacer()
                                    Text(
                                        download.byteCount.formatted(
                                            .byteCount(style: .file).locale(L10n.locale)
                                        )
                                    )
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                downloads.remove(songID: download.id)
                            } label: {
                                Label("ui.downloads.delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("ui.downloads.downloaded")
                } footer: {
                    Text(storageSummary)
                }
            }

            if downloads.downloads.isEmpty && activeDownloads.isEmpty {
                Section {
                    ContentUnavailableView(
                        "ui.downloads.empty",
                        systemImage: "arrow.down.circle",
                        description: Text("ui.downloads.empty.message")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.downloads.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ui.downloads.delete_all", role: .destructive) {
                    showsClearConfirmation = true
                }
                .disabled(downloads.downloads.isEmpty && activeDownloads.isEmpty)
            }
        }
        .confirmationDialog(
            "ui.downloads.delete_all.confirmation",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("ui.downloads.delete_all", role: .destructive) {
                downloads.removeAll()
            }
        } message: {
            Text("ui.downloads.delete_all.message")
        }
    }

    private var activeDownloads: [ActiveSongDownload] {
        downloads.activeDownloads.values.sorted {
            $0.song.name.localizedCompare($1.song.name) == .orderedAscending
        }
    }

    private func progressText(for download: ActiveSongDownload) -> String {
        let received = download.receivedByteCount.formatted(
            .byteCount(style: .file).locale(L10n.locale)
        )
        guard let expected = download.expectedByteCount else {
            return received
        }
        let total = expected.formatted(
            .byteCount(style: .file).locale(L10n.locale)
        )
        let percentage = download.fractionCompleted?.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(L10n.locale)
        ) ?? ""
        return "\(received) / \(total)  \(percentage)"
    }

    private var storageSummary: String {
        L10n.format(
            "ui.downloads.summary",
            downloads.downloads.count,
            L10n.byteCount(downloads.totalByteCount)
        )
    }
}
