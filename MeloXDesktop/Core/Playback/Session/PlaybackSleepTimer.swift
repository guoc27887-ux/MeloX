import Foundation
import Observation

@MainActor
@Observable
final class PlaybackSleepTimer {
    private(set) var endDate: Date?

    var isActive: Bool {
        endDate != nil
    }

    @ObservationIgnored
    private var expirationTask: Task<Void, Never>?

    @ObservationIgnored
    private var expirationHandler: (() -> Void)?

    func setExpirationHandler(_ handler: @escaping () -> Void) {
        expirationHandler = handler
    }

    func start(duration: TimeInterval) {
        guard duration.isFinite, duration > 0 else { return }

        expirationTask?.cancel()

        let deadline = Date.now.addingTimeInterval(duration)
        endDate = deadline
        expirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  self.endDate == deadline else {
                return
            }

            self.endDate = nil
            self.expirationTask = nil
            self.expirationHandler?()
        }
    }

    func cancel() {
        expirationTask?.cancel()
        expirationTask = nil
        endDate = nil
    }
}
