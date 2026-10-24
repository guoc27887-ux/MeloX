#if os(iOS)
import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchSyncService: NSObject {
    private let settings: AppSettings
    private var refreshTask: Task<Void, Never>?
    private var lastPublishedCookie: String?
    private var isStarted = false

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    func start() {
        guard !isStarted, WCSession.isSupported() else { return }
        isStarted = true

        let session = WCSession.default
        session.delegate = self
        session.activate()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.publishSnapshot()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func publishSnapshot(force: Bool = false) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }

        let cookie = settings.cookie
        if !force, cookie == lastPublishedCookie {
            return
        }
        lastPublishedCookie = cookie
        let snapshot = makeSnapshot()
        let message = MeloXWatchEnvelope.message(snapshot: snapshot)

        do {
            try session.updateApplicationContext(message)
        } catch {
            // The next periodic publication retries the newest state.
        }

        if force, session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    private func makeSnapshot() -> MeloXWatchSnapshot {
        let now = Date()
        return MeloXWatchSnapshot(
            account: MeloXWatchAccountSnapshot(
                cookie: settings.cookie,
                nickname: nil,
                avatarURLString: nil,
                updatedAt: now
            ),
            updatedAt: now
        )
    }

    private func handle(_ envelope: MeloXWatchEnvelope) async {
        switch envelope.kind {
        case .requestSnapshot:
            publishSnapshot(force: true)
        case .account:
            guard let account = envelope.account else { return }
            settings.cookie = account.cookie
            publishSnapshot(force: true)
        case .snapshot:
            break
        }
    }
}

extension PhoneWatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.publishSnapshot(force: true)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let envelope = MeloXWatchEnvelope.decode(message) else { return }
        Task { @MainActor in
            await self.handle(envelope)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let envelope = MeloXWatchEnvelope.decode(message) else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            await self.handle(envelope)
            replyHandler(
                MeloXWatchEnvelope.message(snapshot: self.makeSnapshot())
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let envelope = MeloXWatchEnvelope.decode(userInfo) else {
            return
        }
        Task { @MainActor in
            await self.handle(envelope)
        }
    }
}

#endif
