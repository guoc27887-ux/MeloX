import Observation

@MainActor
@Observable
final class DesktopPlaybackVolumeController {
    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let player: PlayerStore

    private(set) var systemVolume: Double

    @ObservationIgnored
    private var lastAudibleSystemVolume: Double

    @ObservationIgnored
    private var lastAudibleIndependentVolume: Double

    @ObservationIgnored
    private var systemVolumeObservation: DesktopSystemVolumeObservation?

    var isControlVisible: Bool {
        settings.playerVolumeControlMode != .hidden
    }

    var volume: Double {
        switch settings.playerVolumeControlMode {
        case .independent:
            player.volume
        case .hidden, .system:
            systemVolume
        }
    }

    init(settings: AppSettings, player: PlayerStore) {
        self.settings = settings
        self.player = player

        let initialSystemVolume = DesktopSystemVolumeController.volume() ?? 1
        systemVolume = initialSystemVolume
        lastAudibleSystemVolume = initialSystemVolume > 0.001
            ? initialSystemVolume
            : 0.8
        lastAudibleIndependentVolume = player.volume > 0.001
            ? player.volume
            : 0.8
        systemVolumeObservation = nil

        systemVolumeObservation = DesktopSystemVolumeController.observeVolume {
            [weak self] volume in
            guard let volume else { return }
            Task { @MainActor [weak self] in
                self?.updateSystemVolume(volume)
            }
        }
    }

    func setVolume(_ value: Double) {
        let normalizedValue = min(max(value, 0), 1)

        switch settings.playerVolumeControlMode {
        case .hidden:
            return
        case .independent:
            if normalizedValue > 0.001 {
                lastAudibleIndependentVolume = normalizedValue
            }
            player.setVolume(normalizedValue)
        case .system:
            guard DesktopSystemVolumeController.setVolume(normalizedValue) else {
                refreshSystemVolume()
                return
            }
            updateSystemVolume(normalizedValue)
        }
    }

    func toggleMuted(minimumRestoreVolume: Double = 0.08) {
        guard isControlVisible else { return }

        if volume > 0.001 {
            rememberAudibleVolume(volume)
            setVolume(0)
        } else {
            setVolume(
                max(lastAudibleVolume, min(max(minimumRestoreVolume, 0), 1))
            )
        }
    }

    func applyControlMode() {
        player.applyVolumeControlMode()
        if settings.playerVolumeControlMode != .independent {
            refreshSystemVolume()
        }
    }

    private var lastAudibleVolume: Double {
        settings.playerVolumeControlMode == .independent
            ? lastAudibleIndependentVolume
            : lastAudibleSystemVolume
    }

    private func rememberAudibleVolume(_ volume: Double) {
        guard volume > 0.001 else { return }

        if settings.playerVolumeControlMode == .independent {
            lastAudibleIndependentVolume = volume
        } else {
            lastAudibleSystemVolume = volume
        }
    }

    private func refreshSystemVolume() {
        guard let volume = DesktopSystemVolumeController.volume() else { return }
        updateSystemVolume(volume)
    }

    private func updateSystemVolume(_ volume: Double) {
        let normalizedValue = min(max(volume, 0), 1)
        systemVolume = normalizedValue
        if normalizedValue > 0.001 {
            lastAudibleSystemVolume = normalizedValue
        }
    }
}
