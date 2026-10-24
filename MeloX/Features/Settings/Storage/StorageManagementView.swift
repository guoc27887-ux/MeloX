import SwiftUI

struct StorageManagementView: View {
    @Environment(DownloadStore.self) private var downloads
    @Environment(PlayerStore.self) private var player

    @State private var model = StorageManagementModel()

    var body: some View {
        List {
            overviewSection
            storageItemsSection
            cacheCleanupSection
            maintenanceSection
            if AppFeatureAvailability.downloads {
                destructiveSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.settings.storage.title")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await model.refreshUsage()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshUsage() }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing || model.isBusy)
                .accessibilityLabel("ui.settings.storage.refresh_accessibility")
            }
        }
        .task {
            await model.refreshUsage()
        }
        .onChange(of: downloads.totalByteCount) {
            Task { await model.refreshUsage() }
        }
        .onChange(of: downloads.activeDownloads.count) {
            Task { await model.refreshUsage() }
        }
        .alert(
            "ui.settings.storage.error.title",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ui.settings.storage.managed_content")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if model.hasLoadedUsage {
                            Text(
                                formattedSize(
                                    displayedManagedByteCount
                                )
                            )
                            .font(.title2.weight(.semibold))
                            .contentTransition(.numericText())
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                deviceCapacityView
            }
            .padding(.vertical, 6)

            LabeledContent(
                L10n.string("ui.settings.storage.reclaimable_cache"),
                value: formattedSize(
                    model.usage.reclaimableCacheBytes
                )
            )

            if let operationMessage = model.operationMessage {
                Label(
                    operationMessage,
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("ui.settings.storage.section.overview")
        } footer: {
            Text(
                AppFeatureAvailability.downloads
                    ? L10n.string("ui.settings.storage.overview.footer.downloads")
                    : L10n.string("ui.settings.storage.overview.footer")
            )
        }
    }

    @ViewBuilder
    private var deviceCapacityView: some View {
        if let total = model.usage.deviceTotalBytes,
           let available = model.usage.deviceAvailableBytes,
           total > 0 {
            let used = max(total - available, 0)

            ProgressView(
                value: Double(used),
                total: Double(total)
            )
            .tint(.accentColor)

            HStack {
                Text(L10n.format("ui.settings.storage.device_used", formattedSize(used)))
                Spacer()
                Text(L10n.format("ui.settings.storage.device_available", formattedSize(available)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var storageItemsSection: some View {
        Section("ui.settings.storage.section.items") {
            if AppFeatureAvailability.downloads {
                NavigationLink {
                    DownloadsView()
                } label: {
                    storageUsageRow(
                        title: L10n.string("ui.settings.storage.downloads_cache"),
                        subtitle:
                            L10n.format("ui.common.song_count", downloads.downloads.count),
                        systemImage: "arrow.down.circle.fill",
                        byteCount: model.usage.downloadsBytes
                    )
                }
            }

            storageUsageRow(
                title: L10n.string("ui.settings.storage.network_cache"),
                subtitle: L10n.string("ui.settings.storage.network_cache.subtitle"),
                systemImage: "photo.stack",
                byteCount: model.usage.networkCacheBytes
            )

            storageUsageRow(
                title: L10n.string("ui.settings.storage.temporary_files"),
                subtitle: L10n.string("ui.settings.storage.temporary_files.subtitle"),
                systemImage: "waveform.path",
                byteCount: model.usage.temporaryFilesBytes
            )

            storageUsageRow(
                title: L10n.string("ui.settings.storage.database"),
                subtitle:
                    AppFeatureAvailability.downloads
                        ? L10n.string("ui.settings.storage.database.subtitle.downloads")
                        : L10n.string("ui.settings.storage.database.subtitle"),
                systemImage: "cylinder.split.1x2",
                byteCount: model.usage.databaseBytes
            )
        }
    }

    private var cacheCleanupSection: some View {
        Section {
            cleanupButton(
                action: .allCaches,
                title: L10n.string("ui.settings.storage.clear_all_caches"),
                subtitle: L10n.string("ui.settings.storage.clear_all_caches.subtitle"),
                systemImage: "eraser",
                byteCount: model.usage.reclaimableCacheBytes
            )

            cleanupButton(
                action: .networkCache,
                title: L10n.string("ui.settings.storage.clear_network_cache"),
                subtitle: L10n.string("ui.settings.storage.clear_network_cache.subtitle"),
                systemImage: "photo.on.rectangle.angled",
                byteCount: model.usage.networkCacheBytes
            )

            cleanupButton(
                action: .temporaryFiles,
                title: L10n.string("ui.settings.storage.clear_temporary_files"),
                subtitle:
                    AppFeatureAvailability.downloads
                        ? L10n.string("ui.settings.storage.clear_temporary_files.subtitle.downloads")
                        : L10n.string("ui.settings.storage.clear_temporary_files.subtitle"),
                systemImage: "waveform",
                byteCount: model.usage.temporaryFilesBytes
            )
        } header: {
            Text("ui.settings.storage.section.cache_cleanup")
        } footer: {
            Text(
                AppFeatureAvailability.downloads
                    ? L10n.string("ui.settings.storage.cache_cleanup.footer.downloads")
                    : L10n.string("ui.settings.storage.cache_cleanup.footer")
            )
        }
    }

    private var maintenanceSection: some View {
        Section {
            if AppFeatureAvailability.downloads {
                cleanupButton(
                    action: .repairDownloads,
                    title: L10n.string("ui.settings.storage.repair_downloads"),
                    subtitle: L10n.string("ui.settings.storage.repair_downloads.subtitle"),
                    systemImage: "wrench.and.screwdriver",
                    byteCount: nil,
                    disabled: !downloads.activeDownloads.isEmpty
                )

                cleanupButton(
                    action: .automaticCacheHistory,
                    title: L10n.string("ui.settings.storage.reset_cache_history"),
                    subtitle: L10n.string("ui.settings.storage.reset_cache_history.subtitle"),
                    systemImage: "arrow.counterclockwise",
                    byteCount: nil
                )
            }

            Button {
                Task {
                    await model.perform(
                        .optimizeDatabase,
                        downloads: downloads,
                        player: player
                    )
                }
            } label: {
                operationLabel(
                    action: .optimizeDatabase,
                    title: L10n.string("ui.settings.storage.optimize_database"),
                    subtitle: L10n.string("ui.settings.storage.optimize_database.subtitle"),
                    systemImage: "cylinder.split.1x2",
                    byteCount: model.usage.databaseBytes
                )
            }
            .disabled(
                model.isBusy
                    || (
                        AppFeatureAvailability.downloads
                            && !downloads.activeDownloads.isEmpty
                    )
            )
        } header: {
            Text("ui.settings.storage.section.maintenance")
        } footer: {
            if AppFeatureAvailability.downloads,
               !downloads.activeDownloads.isEmpty {
                Text("ui.settings.storage.maintenance.footer.active_downloads")
            }
        }
    }

    private var destructiveSection: some View {
        Section {
            Button(role: .destructive) {
                model.confirmation = .allDownloads
            } label: {
                operationLabel(
                    action: .allDownloads,
                    title: L10n.string("ui.settings.storage.delete_all_downloads"),
                    subtitle: L10n.string("ui.settings.storage.delete_all_downloads.subtitle"),
                    systemImage: "trash",
                    byteCount: model.usage.downloadsBytes
                )
            }
            .disabled(
                model.isBusy
                    || (
                        downloads.downloads.isEmpty
                            && downloads.activeDownloads.isEmpty
                    )
            )
            .confirmationDialog(
                StorageCleanupAction.allDownloads.title,
                isPresented:
                    confirmationIsPresented(
                        for: .allDownloads
                    ),
                titleVisibility: .visible
            ) {
                confirmationActions(for: .allDownloads)
            } message: {
                Text(
                    StorageCleanupAction
                        .allDownloads
                        .confirmationMessage
                )
            }
        } header: {
            Text("ui.settings.storage.section.destructive")
        } footer: {
            Text("ui.settings.storage.destructive.footer")
        }
    }

    private func storageUsageRow(
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64
    ) -> some View {
        LabeledContent {
            Text(formattedSize(byteCount))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
            }
        }
    }

    private func cleanupButton(
        action: StorageCleanupAction,
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64?,
        disabled: Bool = false
    ) -> some View {
        Button {
            model.confirmation = action
        } label: {
            operationLabel(
                action: action,
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                byteCount: byteCount
            )
        }
        .disabled(model.isBusy || disabled)
        .confirmationDialog(
            action.title,
            isPresented:
                confirmationIsPresented(for: action),
            titleVisibility: .visible
        ) {
            confirmationActions(for: action)
        } message: {
            Text(action.confirmationMessage)
        }
    }

    private func operationLabel(
        action: StorageCleanupAction,
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64?
    ) -> some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }

            Spacer(minLength: 8)

            if model.activeOperation == action {
                ProgressView()
                    .controlSize(.small)
            } else if let byteCount {
                Text(formattedSize(byteCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .contentShape(.rect)
    }

    private func confirmationIsPresented(
        for action: StorageCleanupAction
    ) -> Binding<Bool> {
        Binding(
            get: { model.confirmation == action },
            set: { isPresented in
                if !isPresented,
                   model.confirmation == action {
                    model.confirmation = nil
                }
            }
        )
    }

    @ViewBuilder
    private func confirmationActions(
        for action: StorageCleanupAction
    ) -> some View {
        Button(
            action.confirmButtonTitle,
            role: .destructive
        ) {
            Task {
                await model.perform(
                    action,
                    downloads: downloads,
                    player: player
                )
            }
        }
        Button("ui.common.cancel", role: .cancel) {}
    }

    private func formattedSize(_ byteCount: Int64) -> String {
        L10n.byteCount(byteCount)
    }

    private var displayedManagedByteCount: Int64 {
        guard !AppFeatureAvailability.downloads else {
            return model.usage.totalManagedBytes
        }
        return max(
            model.usage.totalManagedBytes
                - model.usage.downloadsBytes,
            0
        )
    }
}
