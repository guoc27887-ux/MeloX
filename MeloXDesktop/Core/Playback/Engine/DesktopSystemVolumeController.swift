import AudioToolbox
import CoreAudio
import Dispatch

nonisolated enum DesktopSystemVolumeController {
    static func volume() -> Double? {
        guard let deviceID = defaultOutputDevice() else { return nil }

        if isMuted(on: deviceID) {
            return 0
        }

        for address in volumeAddresses {
            if let value = readVolume(on: deviceID, address: address) {
                return Double(value)
            }
        }

        let channelVolumes = [UInt32(1), UInt32(2)].compactMap { channel in
            readVolume(
                on: deviceID,
                address: volumeAddress(
                    selector: kAudioDevicePropertyVolumeScalar,
                    element: channel
                )
            )
        }
        guard !channelVolumes.isEmpty else { return nil }
        return Double(channelVolumes.reduce(0, +) / Float32(channelVolumes.count))
    }

    @discardableResult
    static func setVolume(_ value: Double) -> Bool {
        guard let deviceID = defaultOutputDevice() else { return false }
        var scalar = Float32(min(max(value, 0), 1))

        for address in volumeAddresses where isSettable(on: deviceID, address: address) {
            var mutableAddress = address
            let status = AudioObjectSetPropertyData(
                deviceID,
                &mutableAddress,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &scalar
            )
            if status == noErr {
                unmuteIfNeeded(on: deviceID, volume: scalar)
                return true
            }
        }

        var changedChannel = false
        for channel in [UInt32(1), UInt32(2)] {
            var address = volumeAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                element: channel
            )
            guard isSettable(on: deviceID, address: address) else { continue }
            let status = AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &scalar
            )
            changedChannel = changedChannel || status == noErr
        }
        if changedChannel {
            unmuteIfNeeded(on: deviceID, volume: scalar)
        }
        return changedChannel
    }

    static func observeVolume(
        _ changeHandler: @escaping @Sendable (Double?) -> Void
    ) -> DesktopSystemVolumeObservation {
        DesktopSystemVolumeObservation(changeHandler: changeHandler)
    }

    fileprivate static var volumeAddresses: [AudioObjectPropertyAddress] {
        [
            volumeAddress(
                selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                element: kAudioObjectPropertyElementMain
            ),
            volumeAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                element: kAudioObjectPropertyElementMain
            ),
        ]
    }

    fileprivate static var muteAddresses: [AudioObjectPropertyAddress] {
        [
            volumeAddress(
                selector: kAudioDevicePropertyMute,
                element: kAudioObjectPropertyElementMain
            ),
            volumeAddress(
                selector: kAudioDevicePropertyMute,
                element: 1
            ),
            volumeAddress(
                selector: kAudioDevicePropertyMute,
                element: 2
            ),
        ]
    }

    fileprivate static var observedPropertyAddresses:
        [AudioObjectPropertyAddress] {
        volumeAddresses
            + [UInt32(1), UInt32(2)].map { channel in
                volumeAddress(
                    selector: kAudioDevicePropertyVolumeScalar,
                    element: channel
                )
            }
            + muteAddresses
    }

    fileprivate static var defaultOutputDeviceAddress:
        AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    fileprivate static func defaultOutputDevice() -> AudioDeviceID? {
        var address = defaultOutputDeviceAddress
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func readVolume(
        on deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Float32? {
        var mutableAddress = address
        guard AudioObjectHasProperty(deviceID, &mutableAddress) else { return nil }
        var scalar = Float32.zero
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &mutableAddress,
            0,
            nil,
            &size,
            &scalar
        )
        guard status == noErr else { return nil }
        return min(max(scalar, 0), 1)
    }

    private static func isMuted(on deviceID: AudioDeviceID) -> Bool {
        muteAddresses.contains { address in
            readMute(on: deviceID, address: address) == true
        }
    }

    private static func readMute(
        on deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool? {
        var mutableAddress = address
        guard AudioObjectHasProperty(deviceID, &mutableAddress) else { return nil }
        var muted = UInt32.zero
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &mutableAddress,
            0,
            nil,
            &size,
            &muted
        )
        guard status == noErr else { return nil }
        return muted != 0
    }

    private static func unmuteIfNeeded(
        on deviceID: AudioDeviceID,
        volume: Float32
    ) {
        guard volume > 0.001 else { return }
        var muted = UInt32.zero

        for var address in muteAddresses
        where isSettable(on: deviceID, address: address) {
            AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<UInt32>.size),
                &muted
            )
        }
    }

    private static func isSettable(
        on deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var mutableAddress = address
        guard AudioObjectHasProperty(deviceID, &mutableAddress) else { return false }
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(
            deviceID,
            &mutableAddress,
            &settable
        )
        return status == noErr && settable.boolValue
    }

    fileprivate static func volumeAddress(
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }
}

nonisolated final class DesktopSystemVolumeObservation: @unchecked Sendable {
    private let listenerQueue = DispatchQueue(
        label: "MeloX.DesktopSystemVolumeObservation"
    )
    private let changeHandler: @Sendable (Double?) -> Void
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var observesDefaultOutputDevice = false
    private var observedDeviceID: AudioDeviceID?
    private var observedAddresses: [AudioObjectPropertyAddress] = []

    fileprivate init(
        changeHandler: @escaping @Sendable (Double?) -> Void
    ) {
        self.changeHandler = changeHandler

        let defaultOutputListener: AudioObjectPropertyListenerBlock = {
            [weak self] _, _ in
            self?.defaultOutputDeviceDidChange()
        }
        let volumeListener: AudioObjectPropertyListenerBlock = {
            [weak self] _, _ in
            self?.publishVolume()
        }
        self.defaultOutputListener = defaultOutputListener
        self.volumeListener = volumeListener

        installDefaultOutputListener(defaultOutputListener)
        replaceDeviceObservation(using: volumeListener)
        publishVolume()
    }

    deinit {
        removeDeviceObservation()
        guard observesDefaultOutputDevice,
              let defaultOutputListener else { return }

        var address = DesktopSystemVolumeController.defaultOutputDeviceAddress
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            defaultOutputListener
        )
    }

    private func installDefaultOutputListener(
        _ listener: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = DesktopSystemVolumeController.defaultOutputDeviceAddress
        observesDefaultOutputDevice = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            listener
        ) == noErr
    }

    private func defaultOutputDeviceDidChange() {
        guard let volumeListener else { return }
        replaceDeviceObservation(using: volumeListener)
        publishVolume()
    }

    private func replaceDeviceObservation(
        using listener: @escaping AudioObjectPropertyListenerBlock
    ) {
        removeDeviceObservation()
        guard let deviceID = DesktopSystemVolumeController
            .defaultOutputDevice() else { return }

        observedDeviceID = deviceID
        for candidate in DesktopSystemVolumeController.observedPropertyAddresses {
            var address = candidate
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let status = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &address,
                listenerQueue,
                listener
            )
            if status == noErr {
                observedAddresses.append(candidate)
            }
        }
    }

    private func removeDeviceObservation() {
        guard let observedDeviceID,
              let volumeListener else {
            observedAddresses.removeAll()
            self.observedDeviceID = nil
            return
        }

        for candidate in observedAddresses {
            var address = candidate
            AudioObjectRemovePropertyListenerBlock(
                observedDeviceID,
                &address,
                listenerQueue,
                volumeListener
            )
        }
        observedAddresses.removeAll()
        self.observedDeviceID = nil
    }

    private func publishVolume() {
        changeHandler(DesktopSystemVolumeController.volume())
    }
}
