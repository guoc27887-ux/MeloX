import SwiftUI

struct OnboardingWelcomeView: View {
    let continueAction: () -> Void
    let showLicenses: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(.rect(cornerRadius: 25))
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("MeloX")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("ui.onboarding.welcome.subtitle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
            .padding(.horizontal, 32)

            Spacer(minLength: 36)

            Text("ui.legal.unofficial_disclaimer")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                Button(action: continueAction) {
                    Text("ui.common.continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Button("ui.legal.projects_licenses.title", action: showLicenses)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct OnboardingAccountView: View {
    let profile: AccountProfile?
    let isLoggedIn: Bool
    let login: () -> Void
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                accountIdentity

                if isLoggedIn {
                    Text("ui.onboarding.account.logged_in_message")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    signInBenefits
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 32)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if isLoggedIn {
                    prominentButton(L10n.string("ui.onboarding.start"), action: finish)
                } else {
                    prominentButton(L10n.string("ui.account.login_netease"), action: login)

                    Button("ui.common.maybe_later", action: finish)
                        .font(.headline)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .navigationTitle("ui.service.netease_cloud_music")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var accountIdentity: some View {
        if isLoggedIn {
            AsyncImage(url: profile?.artworkURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, height: 96)
            .background(.quaternary, in: .circle)
            .clipShape(.circle)

            VStack(spacing: 8) {
                Text(profile?.nickname ?? L10n.string("ui.account.netease_account"))
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Label("ui.account.logged_in", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("ui.onboarding.account.connect")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("ui.onboarding.account.connect_message")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signInBenefits: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("ui.onboarding.benefit.sync_library", systemImage: "music.note.list")
            Label("ui.onboarding.benefit.personalized_content", systemImage: "sparkles")
            Label("ui.onboarding.benefit.local_cookie", systemImage: "lock.iphone")
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prominentButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
