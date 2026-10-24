import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: MeloXWatchSnapshot = .empty
    @Published private(set) var activationState:
        WCSessionActivationState = .notActivated
    @Published private(set) var isReachable = false
    @Published private(set) var lastErrorMessage: String?

    private let accountStore: WatchAccountStore

    init(accountStore: WatchAccountStore) {
        self.accountStore = accountStore
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        activationState = session.activationState
        isReachable = session.isReachable
        if session.activationState == .notActivated {
            session.activate()
        } else {
            apply(message: session.receivedApplicationContext)
            requestSnapshot()
        }
    }

    func requestSnapshot() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(
                MeloXWatchEnvelope.snapshotRequestMessage
            ) { [weak self] reply in
                Task { @MainActor in
                    self?.apply(message: reply)
                }
            } errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func sendAccountToPhone() {
        guard WCSession.isSupported(), !accountStore.cookie.isEmpty else {
            return
        }
        let account = MeloXWatchAccountSnapshot(
            cookie: accountStore.cookie,
            nickname: accountStore.profile?.nickname,
            avatarURLString: accountStore.profile?.avatarURLString,
            updatedAt: Date()
        )
        let message = MeloXWatchEnvelope.message(account: account)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: nil
            ) { [weak self] error in
                Task { @MainActor in
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func apply(message: [String: Any]) {
        guard let envelope = MeloXWatchEnvelope.decode(message),
              envelope.kind == .snapshot,
              let snapshot = envelope.snapshot else {
            return
        }
        self.snapshot = snapshot
        accountStore.applyPhoneSnapshot(snapshot.account)
        lastErrorMessage = nil
    }
}

extension WatchConnectivityStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = session.isReachable
            self.lastErrorMessage = error?.localizedDescription
            self.apply(message: session.receivedApplicationContext)
            self.requestSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestSnapshot()
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.apply(message: applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.apply(message: message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.apply(message: userInfo)
        }
    }
}
