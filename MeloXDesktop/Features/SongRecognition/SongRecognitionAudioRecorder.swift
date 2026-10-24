@preconcurrency import AVFoundation
import Foundation

enum SongRecognitionRecordingError: LocalizedError {
    case microphonePermissionDenied
    case microphoneUnavailable
    case recordingFailed(String)
    case recordingTimedOut
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            L10n.string("ui.recognition.error.microphone_permission")
        case .microphoneUnavailable:
            L10n.string("ui.recognition.error.microphone_unavailable")
        case .recordingFailed(let message):
            L10n.format("ui.recognition.error.recording_failed", message)
        case .recordingTimedOut:
            L10n.string("ui.recognition.error.recording_timed_out")
        case .conversionFailed:
            L10n.string("ui.recognition.error.conversion_failed")
        }
    }

    var opensSystemSettings: Bool {
        if case .microphonePermissionDenied = self {
            true
        } else {
            false
        }
    }
}

struct SongRecognitionAudioSnapshot {
    let samples: [Float]
    let duration: Int
    let totalDuration: Int
    let reachedLimit: Bool
}

@MainActor
final class SongRecognitionAudioRecorder {
    static let fingerprintSampleRate = 8_000.0
    private static let continuousWindowDuration = 9

    private var engine: AVAudioEngine?
    private var sampleBuffer: SongRecognitionSampleBuffer?
    private var sourceSampleRate = 0.0
    private var isTapInstalled = false

    func requestPermission() async throws {
        try await ensureMicrophonePermission()
    }

    func start(maximumDuration: Int?) async throws {
        stop()
        resetCapture()

        if let maximumDuration,
           maximumDuration <= 0 {
            throw SongRecognitionRecordingError.conversionFailed
        }

        try await ensureMicrophonePermission()
        try Task.checkCancellation()

        let recordingEngine = AVAudioEngine()
        let inputNode = recordingEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              inputFormat.commonFormat == .pcmFormatFloat32 else {
            throw SongRecognitionRecordingError.microphoneUnavailable
        }

        let retainedDuration =
            maximumDuration ?? Self.continuousWindowDuration
        let retainedFrameCount = Int(
            (Double(retainedDuration) * inputFormat.sampleRate)
                .rounded(.up)
        )
        let recordingBuffer = SongRecognitionSampleBuffer(
            retainedFrameCount: retainedFrameCount,
            stoppingFrameCount: maximumDuration.map {
                Int(
                    (Double($0) * inputFormat.sampleRate)
                        .rounded(.up)
                )
            }
        )

        sampleBuffer = recordingBuffer
        sourceSampleRate = inputFormat.sampleRate
        engine = recordingEngine

        inputNode.installTap(
            onBus: 0,
            bufferSize: 2_048,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard recordingBuffer.append(buffer) else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      sampleBuffer === recordingBuffer else {
                    return
                }
                stopEngine()
            }
        }
        isTapInstalled = true

        do {
            recordingEngine.prepare()
            try recordingEngine.start()
        } catch {
            stop()
            resetCapture()
            throw SongRecognitionRecordingError.recordingFailed(
                error.localizedDescription
            )
        }
    }

    func snapshot() throws -> SongRecognitionAudioSnapshot? {
        guard let sampleBuffer,
              sourceSampleRate > 0 else {
            return nil
        }

        let rawSnapshot = sampleBuffer.snapshot()
        let availableDuration = Int(
            Double(rawSnapshot.samples.count)
                / sourceSampleRate
        )
        let totalDuration = Int(
            Double(rawSnapshot.totalFrameCount)
                / sourceSampleRate
        )
        guard availableDuration > 0 else { return nil }

        let sourceFrameCount = min(
            rawSnapshot.samples.count,
            Int(
                (Double(availableDuration) * sourceSampleRate)
                    .rounded(.down)
            )
        )
        let sourceSamples = Array(
            rawSnapshot.samples.suffix(sourceFrameCount)
        )
        let targetFrameCount =
            availableDuration * Int(Self.fingerprintSampleRate)

        return SongRecognitionAudioSnapshot(
            samples: try resample(
                sourceSamples,
                sourceSampleRate: sourceSampleRate,
                targetFrameCount: targetFrameCount
            ),
            duration: availableDuration,
            totalDuration: totalDuration,
            reachedLimit: rawSnapshot.reachedLimit
        )
    }

    func cancel() {
        stop()
    }

    func prepareForConcurrentPlayback() {
        // macOS mixes app playback and microphone capture without an
        // AVAudioSession category transition.
    }

    func stop() {
        stopEngine()
    }

    private func stopEngine() {
        guard let engine else { return }
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.stop()
        self.engine = nil
    }

    private func resetCapture() {
        sampleBuffer = nil
        sourceSampleRate = 0
    }

    private func ensureMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .denied, .restricted:
            throw SongRecognitionRecordingError
                .microphonePermissionDenied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                throw SongRecognitionRecordingError
                    .microphonePermissionDenied
            }
        @unknown default:
            throw SongRecognitionRecordingError
                .microphonePermissionDenied
        }
    }

    private func resample(
        _ samples: [Float],
        sourceSampleRate: Double,
        targetFrameCount: Int
    ) throws -> [Float] {
        guard !samples.isEmpty,
              targetFrameCount > 0 else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        if sourceSampleRate == Self.fingerprintSampleRate {
            return normalizedFrameCount(
                samples,
                targetFrameCount: targetFrameCount
            )
        }

        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceSampleRate,
            channels: 1,
            interleaved: false
        ),
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.fingerprintSampleRate,
            channels: 1,
            interleaved: false
        ),
        let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(targetFrameCount + 32)
        ),
        let inputChannel = inputBuffer.floatChannelData?[0],
        let converter = AVAudioConverter(
            from: sourceFormat,
            to: targetFormat
        ) else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            inputChannel.update(
                from: baseAddress,
                count: samples.count
            )
        }
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        converter.primeMethod = .none

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(
            to: outputBuffer,
            error: &conversionError
        ) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error,
              conversionError == nil,
              let outputChannel = outputBuffer.floatChannelData?[0] else {
            throw SongRecognitionRecordingError.conversionFailed
        }

        let output = Array(
            UnsafeBufferPointer(
                start: outputChannel,
                count: Int(outputBuffer.frameLength)
            )
        )
        return normalizedFrameCount(
            output,
            targetFrameCount: targetFrameCount
        )
    }

    private func normalizedFrameCount(
        _ samples: [Float],
        targetFrameCount: Int
    ) -> [Float] {
        if samples.count >= targetFrameCount {
            return Array(samples.prefix(targetFrameCount))
        }
        return samples + Array(
            repeating: 0,
            count: targetFrameCount - samples.count
        )
    }
}
