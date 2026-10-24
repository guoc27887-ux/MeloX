import SwiftUI

private enum SettingsAccountSheet: String, Identifiable {
    case neteaseLogin

    var id: String { rawValue }
}

struct SettingsAccountSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var presentedSheet: SettingsAccountSheet?
    @State private var showsLogoutConfirmation = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 10) {
                accountOverview

                if !library.isLoggedIn {
                    Text("ui.settings.account.cookie.footer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                }
            }

            if library.isLoggedIn {
                logoutCard
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .neteaseLogin:
                NavigationStack {
                    NeteaseLoginView()
                }
            }
        }
        .confirmationDialog(
            "ui.settings.account.logout.confirmation",
            isPresented: $showsLogoutConfirmation
        ) {
            Button("ui.settings.account.logout", role: .destructive) {
                logout()
            }
        } message: {
            Text(
                AppFeatureAvailability.downloads
                    ? L10n.string("ui.settings.account.logout.message.downloads")
                    : L10n.string("ui.settings.account.logout.message")
            )
        }
    }

    @ViewBuilder
    private var accountOverviewContent: some View {
        if library.isLoggedIn, let profile = library.profile {
            NavigationLink(value: SettingsRoute.accountHome) {
                HStack(spacing: 16) {
                    accountAvatar(profile)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.nickname)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(accountSubtitle(profile))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("ui.settings.account.open.hint")
        } else if library.isLoggedIn {
            HStack(spacing: 16) {
                ProgressView()
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 5) {
                    Text("ui.settings.account.netease_account")
                        .font(.title3.weight(.semibold))
                    Text("ui.settings.account.loading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                presentedSheet = .neteaseLogin
            } label: {
                HStack(spacing: 16) {
                    Image(
                        systemName:
                            "person.crop.circle.badge.plus"
                    )
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                    .frame(width: 60, height: 60)
                    .background(.quaternary, in: .circle)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ui.settings.account.login")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("ui.settings.account.login.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private var accountOverview: some View {
        accountOverviewContent
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(
                maxWidth: .infinity,
                minHeight: 100,
                alignment: .leading
            )
            .background {
                RoundedRectangle(
                    cornerRadius: 28,
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

    private var logoutCard: some View {
        Button(role: .destructive) {
            showsLogoutConfirmation = true
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        "rectangle.portrait.and.arrow.right"
                )
                .font(.title3.weight(.medium))
                .frame(width: 30)

                Text("ui.settings.account.logout")
                    .font(.body.weight(.medium))

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .contentShape(.rect)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
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

    private func accountAvatar(_ profile: AccountProfile) -> some View {
        AsyncImage(url: profile.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(.quaternary, in: .circle)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private func accountSubtitle(_ profile: AccountProfile) -> String {
        if let detail = library.accountDetail, detail.level > 0 {
            return L10n.format(
                "ui.settings.account.subtitle.level",
                detail.level,
                profile.id
            )
        }
        return L10n.format("ui.settings.account.subtitle", profile.id)
    }

    private func logout() {
        settings.clearAccount()
        library.clearAccountData()
        Task {
            await NeteaseWebCookieStore.clear()
        }
    }
}
