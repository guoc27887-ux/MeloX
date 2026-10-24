import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ScreenAwakeCoordinator {
    @ObservationIgnored
    private var activeRequests: Set<UUID> = []

    @ObservationIgnored
    private var activity: NSObjectProtocol?

    func setKeepsScreenAwake(_ keepsScreenAwake: Bool, for requestID: UUID) {
        let requestChanged: Bool

        if keepsScreenAwake {
            requestChanged = activeRequests.insert(requestID).inserted
        } else {
            requestChanged = activeRequests.remove(requestID) != nil
        }

        guard requestChanged else { return }
        if activeRequests.isEmpty {
            if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        } else if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: L10n.string("ui.desktop.screen_awake.reason")
            )
        }
    }
}

extension View {
    func keepsScreenAwake(_ isEnabled: Bool) -> some View {
        modifier(KeepsScreenAwakeModifier(isEnabled: isEnabled))
    }
}

private struct KeepsScreenAwakeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ScreenAwakeCoordinator.self) private var coordinator

    let isEnabled: Bool

    @State private var requestID = UUID()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                updateRequest()
            }
            .onDisappear {
                isVisible = false
                coordinator.setKeepsScreenAwake(false, for: requestID)
            }
            .onChange(of: isEnabled) { _, _ in
                updateRequest()
            }
            .onChange(of: scenePhase) { _, _ in
                updateRequest()
            }
    }

    private func updateRequest() {
        coordinator.setKeepsScreenAwake(
            isEnabled && isVisible && scenePhase == .active,
            for: requestID
        )
    }
}
