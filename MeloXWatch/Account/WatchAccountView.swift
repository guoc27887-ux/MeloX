import SwiftUI

struct WatchAccountView: View {
    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore

    let api: WatchNeteaseAPI

    var body: some View {
        List {
            if account.isLoggedIn {
                Section {
                    HStack(spacing: 10) {
                        AsyncImage(
                            url: WatchArtworkURL.make(
                                from: account.profile?.avatarURLString,
                                dimension: 160
                            )
                        ) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(.circle)

                        VStack(alignment: .leading) {
                            Text(account.profile?.nickname ?? L10n.string("ui.account.netease_account"))
                                .font(.headline)
                            Text(account.source.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("ui.watch.account.sync") {
                    Button {
                        connectivity.sendAccountToPhone()
                    } label: {
                        Label("ui.watch.account.sync_to_iphone", systemImage: "iphone")
                    }

                    Button {
                        account.usePhoneLogin()
                        connectivity.requestSnapshot()
                    } label: {
                        Label(
                            "ui.watch.account.use_iphone_login",
                            systemImage: "applewatch.radiowaves.left.and.right"
                        )
                    }
                }

                Section {
                    Button("ui.watch.account.sign_out", role: .destructive) {
                        account.clear()
                    }
                }
            } else {
                Section {
                    NavigationLink {
                        WatchQRLoginView(api: api)
                    } label: {
                        Label("ui.watch.account.qr_login", systemImage: "qrcode")
                    }

                    Button {
                        account.usePhoneLogin()
                        connectivity.requestSnapshot()
                    } label: {
                        Label(
                            "ui.watch.account.sync_from_iphone",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                }

                Section {
                    Text("ui.watch.account.login_explanation")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = connectivity.lastErrorMessage {
                Section("ui.watch.account.connection_status") {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("ui.account.netease_account")
        .task {
            guard account.isLoggedIn,
                  account.profile == nil else {
                return
            }
            if let profile = try? await api.accountProfile() {
                account.updateProfile(profile)
            }
        }
    }
}
