import SwiftUI

struct TabLayoutSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Label(
                        AppTab.recommended.settingsTitle,
                        systemImage: AppTab.recommended.systemImage
                    )

                    Spacer(minLength: 8)

                    Text("ui.settings.tab_layout.pinned_home")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("ui.navigation.recommended")
            } footer: {
                Text("ui.settings.tab_layout.recommended.footer")
            }

            Section {
                ForEach(
                    AppTab.movablePrimaryContentPages.filter(
                        settings.isNavigationTabEnabled
                    )
                ) { tab in
                    placementPicker(for: tab)
                }
            } header: {
                Text("ui.settings.tab_layout.section.content_pages")
            } footer: {
                Text("ui.settings.tab_layout.content_pages.footer")
            }

            Section {
                ForEach(
                    AppTab.libraryContentPages.filter(
                        settings.isNavigationTabEnabled
                    )
                ) { tab in
                    placementPicker(for: tab)
                }
            } header: {
                Text("ui.settings.tab_layout.section.library_local")
            } footer: {
                Text("ui.settings.tab_layout.library_local.footer")
            }

            Section {
                ForEach(settings.homeTabs) { tab in
                    orderRow(
                        for: tab,
                        trailingText:
                            tab == .recommended
                                ? L10n.string("ui.common.fixed")
                                : nil
                    )
                    .moveDisabled(tab == .recommended)
                }
                .onMove { source, destination in
                    var tabs = settings.homeTabs
                    tabs.move(
                        fromOffsets: source,
                        toOffset: destination
                    )
                    settings.setHomeTabOrder(tabs)
                }
            } header: {
                Text("ui.settings.tab_layout.section.home_order")
            } footer: {
                Text("ui.settings.tab_layout.home_order.footer")
            }

            Section {
                ForEach(settings.visibleTabs) { tab in
                    orderRow(
                        for: tab,
                        trailingText: fixedTabDescription(for: tab)
                    )
                    .moveDisabled(tab == .home || tab == .search)
                }
                .onMove { source, destination in
                    var tabs = settings.visibleTabs
                    tabs.move(
                        fromOffsets: source,
                        toOffset: destination
                    )
                    settings.setVisibleTabOrder(tabs)
                }
            } header: {
                Text("ui.settings.tab_layout.section.tab_order")
            } footer: {
                Text("ui.settings.tab_layout.tab_order.footer")
            }

            Section {
                Button(
                    "ui.settings.tab_layout.reset",
                    systemImage: "arrow.counterclockwise",
                    role: .destructive
                ) {
                    showsResetConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.settings.tab_layout.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .confirmationDialog(
            "ui.settings.tab_layout.reset.confirmation",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("ui.settings.tab_layout.reset.action", role: .destructive) {
                settings.resetTabLayout()
            }
            Button("ui.common.cancel", role: .cancel) {}
        } message: {
            Text("ui.settings.tab_layout.reset.message")
        }
    }

    private func placementPicker(
        for tab: AppTab
    ) -> some View {
        Picker(
            selection: Binding(
                get: { settings.placement(for: tab) },
                set: { settings.setPage(tab, placement: $0) }
            )
        ) {
            ForEach(tab.allowedPlacements) { placement in
                Text(placement.title)
                    .tag(placement)
            }
        } label: {
            Label(tab.settingsTitle, systemImage: tab.systemImage)
        }
        .pickerStyle(.menu)
    }

    private func orderRow(
        for tab: AppTab,
        trailingText: String?
    ) -> some View {
        HStack(spacing: 12) {
            Label(tab.settingsTitle, systemImage: tab.systemImage)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    private func fixedTabDescription(
        for tab: AppTab
    ) -> String? {
        switch tab {
        case .home:
            L10n.string("ui.settings.tab_layout.fixed_entry")
        case .search:
            L10n.string("ui.settings.tab_layout.system_fixed")
        default:
            nil
        }
    }
}
