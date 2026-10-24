import SwiftUI

struct DesktopOnboardingDialog: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var page = 0
    @State private var showsLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(pageTitle)
                    .font(.system(size: 30, weight: .bold))
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.red : Color.secondary.opacity(0.22))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 22)

            Divider()

            Group {
                switch page {
                case 0: welcomePage
                case 1: experiencePage
                default: accountPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentTransition(.opacity)

            Divider()

            HStack {
                if page > 0 {
                    Button("ui.common.back") {
                        withAnimation(.easeInOut(duration: 0.22)) { page -= 1 }
                    }
                }

                Spacer()

                if page < 2 {
                    Button("ui.common.continue") {
                        withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if model.library.isLoggedIn {
                    Button("ui.onboarding.start") { finish() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button("ui.desktop.onboarding.sign_in_later") { finish() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("ui.account.login_netease") { showsLogin = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 34)
            .frame(height: 76)
        }
        .frame(width: 760, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled()
        .sheet(isPresented: $showsLogin) {
            DesktopLoginView()
                .environment(model)
        }
    }

    private var pageTitle: String {
        switch page {
        case 0: L10n.string("ui.desktop.onboarding.welcome")
        case 1: L10n.string("ui.desktop.onboarding.configure")
        default: L10n.string("ui.settings.account.netease_account")
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)

            VStack(spacing: 10) {
                Text("MeloX")
                    .font(.system(size: 38, weight: .bold))
                Text("ui.desktop.onboarding.subtitle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 30) {
                onboardingFeature(L10n.string("ui.desktop.onboarding.feature.library"), symbol: "music.note.list")
                onboardingFeature(L10n.string("ui.desktop.onboarding.feature.lyrics"), symbol: "quote.bubble")
                onboardingFeature(L10n.string("ui.desktop.onboarding.feature.downloads_cloud"), symbol: "icloud.and.arrow.down")
            }

            Text("ui.legal.unofficial_disclaimer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Spacer()
        }
        .padding(.horizontal, 42)
    }

    private var experiencePage: some View {
        @Bindable var settings = model.settings
        @Bindable var recognition = model.settings.songRecognition

        return Form {
            Section("ui.desktop.settings.appearance") {
                Picker("ui.desktop.settings.appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.title, systemImage: appearance.systemImage)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("ui.settings.playback.section.playback") {
                Picker("ui.player.playback_quality", selection: $settings.quality) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                Toggle("ui.settings.player_appearance.shrink_paused_artwork", isOn: $settings.shrinksPausedArtwork)
                Toggle("ui.settings.player_appearance.beat_vignette", isOn: $settings.playerBackgroundBeatEffectsEnabled)
            }

            Section("ui.recognition.title") {
                Picker("ui.desktop.onboarding.recognition.default_duration", selection: $recognition.duration) {
                    ForEach(SongRecognitionDuration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                Text("ui.desktop.onboarding.recognition.privacy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var accountPage: some View {
        VStack(spacing: 28) {
            Spacer()

            if let profile = model.library.profile {
                DesktopCircularArtworkView(url: profile.artworkURL)
                    .frame(width: 112, height: 112)
                    .clipShape(.circle)
                VStack(spacing: 7) {
                    Text(profile.nickname)
                        .font(.title.bold())
                    Label("ui.account.logged_in", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 82, weight: .regular))
                    .foregroundStyle(.red)
                VStack(spacing: 9) {
                    Text("ui.onboarding.account.connect")
                        .font(.title.bold())
                    Text("ui.desktop.onboarding.account.message")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }
            }

            VStack(alignment: .leading, spacing: 17) {
                Label("ui.desktop.onboarding.benefit.direct_api", systemImage: "network")
                Label("ui.onboarding.benefit.local_cookie", systemImage: "lock.macwindow")
                Label("ui.desktop.onboarding.benefit.independent_interfaces", systemImage: "macbook.and.iphone")
            }
            .font(.body)

            Spacer()
        }
        .padding(.horizontal, 44)
    }

    private func onboardingFeature(_ title: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.red)
            Text(title)
                .font(.headline)
        }
        .frame(width: 150)
    }

    private func finish() {
        model.settings.completeOnboarding()
        model.ui.sheet = nil
        Task { await model.refreshAll() }
    }
}
