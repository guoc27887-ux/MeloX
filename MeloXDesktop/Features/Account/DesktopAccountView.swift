import SwiftUI

struct DesktopAccountView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var showsLogoutConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ui.desktop.settings.account")
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 20)

            if let profile = model.library.profile {
                loggedInContent(profile)
            } else if model.library.isLoggedIn {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await model.library.refresh(force: true) }
            } else {
                ContentUnavailableView {
                    Label("ui.account.login_netease", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("ui.desktop.account.login_message")
                } actions: {
                    Button("ui.common.login") { model.ui.sheet = .login }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer()
                doneButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 600)
        .confirmationDialog(
            L10n.string("ui.settings.account.logout.confirmation"),
            isPresented: $showsLogoutConfirmation
        ) {
            Button("ui.settings.account.logout", role: .destructive) {
                model.logOut()
            }
            Button("ui.common.cancel", role: .cancel) {}
        }
    }

    private func loggedInContent(_ profile: AccountProfile) -> some View {
        VStack(spacing: 12) {
            accountGroup {
                VStack(spacing: 0) {
                    accountAction(L10n.string("ui.messages.private.title")) {
                        model.ui.sheet = nil
                        model.ui.navigate(to: .section(.messages))
                    }

                    if model.isSectionEnabled(.cloud) {
                        Divider()
                            .padding(.leading, 12)
                        accountAction(L10n.string("ui.navigation.cloud")) {
                            model.ui.sheet = nil
                            model.ui.navigate(to: .section(.cloud))
                        }
                    }

                    if model.isSectionEnabled(.downloads) {
                        Divider()
                            .padding(.leading, 12)
                        accountAction(L10n.string("ui.navigation.downloads")) {
                            model.ui.sheet = nil
                            model.ui.navigate(to: .section(.downloads))
                        }
                    }
                }
            }

            accountGroup {
                accountAction(L10n.string("ui.desktop.account.settings")) {
                    dismiss()
                    openSettings()
                }
            }

            accountGroup {
                Button {
                    showsLogoutConfirmation = true
                } label: {
                    HStack {
                        Text("ui.settings.account.logout")
                        Spacer()
                        Text(profile.nickname)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private func accountAction(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button("ui.common.done") { dismiss() }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 80, height: 30)
            .background(.red, in: .capsule)
            .contentShape(.capsule)
    }

    private func accountGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                Color.primary.opacity(0.045),
                in: .rect(cornerRadius: 12, style: .continuous)
            )
    }
}
