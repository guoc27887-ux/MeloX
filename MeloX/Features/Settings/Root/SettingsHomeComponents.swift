import SwiftUI

struct SettingsHomeToolbarTitle: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(.rect(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            Text("MeloX")
                .font(.headline)
        }
    }
}

struct SettingsHomeSectionCard: View {
    let section: SettingsCatalogSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(section.items.indices, id: \.self) { index in
                    if index > section.items.startIndex {
                        Divider()
                            .padding(.leading, 58)
                    }

                    row(for: section.items[index])
                }
            }
            .background {
                RoundedRectangle(
                    cornerRadius: 26,
                    style: .continuous
                )
                .fill(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    )
                )
            }
        }
    }

    private func row(
        for item: SettingsCatalogItem
    ) -> some View {
        NavigationLink(value: item.route) {
            HStack(spacing: 14) {
                Image(systemName: item.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(minHeight: 68)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsHomeResetCard: View {
    let isResetting: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ui.common.restore")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            Button(role: .destructive, action: action) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3.weight(.medium))
                        .frame(width: 30)

                    Text("ui.settings.reset.card.title")
                        .font(.body.weight(.semibold))

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minHeight: 60)
                .contentShape(.rect)
                .background {
                    RoundedRectangle(
                        cornerRadius: 26,
                        style: .continuous
                    )
                    .fill(
                        Color(
                            uiColor:
                                .secondarySystemGroupedBackground
                        )
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isResetting)

            Text(
                AppFeatureAvailability.downloads
                    ? L10n.string("ui.settings.reset.card.subtitle.downloads")
                    : L10n.string("ui.settings.reset.card.subtitle")
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
        }
    }
}
