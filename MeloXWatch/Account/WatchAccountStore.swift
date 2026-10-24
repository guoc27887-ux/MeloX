import Combine
import Foundation

enum WatchAccountSource: String {
    case none
    case iPhone
    case qrCode

    var title: String {
        switch self {
        case .none: L10n.string("ui.watch.account.source.none")
        case .iPhone: L10n.string("ui.watch.account.source.iphone")
        case .qrCode: L10n.string("ui.watch.account.source.qr")
        }
    }
}

@MainActor
final class WatchAccountStore: ObservableObject {
    @Published private(set) var cookie: String
    @Published private(set) var profile: WatchAccountProfile?
    @Published private(set) var source: WatchAccountSource

    private enum Key {
        static let cookie = "melox.watch.cookie"
        static let profile = "melox.watch.profile"
        static let source = "melox.watch.accountSource"
        static let prefersLocalLogin = "melox.watch.prefersLocalLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cookie = defaults.string(forKey: Key.cookie) ?? ""
        source = WatchAccountSource(
            rawValue: defaults.string(forKey: Key.source) ?? ""
        ) ?? .none
        if let data = defaults.data(forKey: Key.profile) {
            profile = try? JSONDecoder().decode(
                WatchAccountProfile.self,
                from: data
            )
        }
    }

    var isLoggedIn: Bool {
        cookie.contains("MUSIC_U=")
    }

    var prefersLocalLogin: Bool {
        get {
            defaults.object(forKey: Key.prefersLocalLogin) as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: Key.prefersLocalLogin)
        }
    }

    func applyPhoneSnapshot(_ account: MeloXWatchAccountSnapshot) {
        guard !account.cookie.isEmpty,
              !prefersLocalLogin || !isLoggedIn else {
            return
        }
        save(
            cookie: account.cookie,
            profile: profile,
            source: .iPhone
        )
    }

    func saveQRLogin(
        cookie: String,
        profile: WatchAccountProfile?
    ) {
        prefersLocalLogin = true
        save(cookie: cookie, profile: profile, source: .qrCode)
    }

    func updateProfile(_ profile: WatchAccountProfile) {
        self.profile = profile
        persistProfile()
    }

    func usePhoneLogin() {
        prefersLocalLogin = false
        if source == .qrCode {
            clear()
        }
    }

    func clear() {
        cookie = ""
        profile = nil
        source = .none
        defaults.removeObject(forKey: Key.cookie)
        defaults.removeObject(forKey: Key.profile)
        defaults.removeObject(forKey: Key.source)
    }

    private func save(
        cookie: String,
        profile: WatchAccountProfile?,
        source: WatchAccountSource
    ) {
        self.cookie = cookie
        self.profile = profile
        self.source = source
        defaults.set(cookie, forKey: Key.cookie)
        defaults.set(source.rawValue, forKey: Key.source)
        persistProfile()
    }

    private func persistProfile() {
        if let profile,
           let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Key.profile)
        } else {
            defaults.removeObject(forKey: Key.profile)
        }
    }
}
