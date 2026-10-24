@preconcurrency import AVFoundation
import CoreML
import Foundation

nonisolated struct AutoMixAnalysisRequest: Sendable {
    let songID: Int
    let source: PlaybackSource
    let duration: TimeInterval
    let isDownloaded: Bool
}

nonisolated struct AutoMixSpectralProfile: Sendable {
    let low: Float
    let mid: Float
    let high: Float
}

nonisolated struct AutoMixTrackAnalysis: Sendable {
    let bpm: Double
    let confidence: Double
    let beats: [TimeInterval]
    let downbeats: [TimeInterval]
    let regionStart: TimeInterval
    let normalizedEnergy: [Float]
    let loudnessDecibels: [Float]
    let lowFrequencyRatios: [Float]
    let midFrequencyRatios: [Float]
    let highFrequencyRatios: [Float]
    let spectralNovelty: [Float]
    let modelBeatActivations: [Float]
    let modelDownbeatActivations: [Float]
    let featureStatistics: BeatNetFeatureStatistics
    let finalAllZeroSegmentCount: Int
    let analyzedSegmentCount: Int

    func energy(at absoluteTime: TimeInterval) -> Float {
        value(
            in: normalizedEnergy,
            at: absoluteTime
        )
    }

    func loudness(
        at absoluteTime: TimeInterval
    ) -> Float {
        value(
            in: loudnessDecibels,
            at: absoluteTime,
            fallback: -120
        )
    }

    func spectralProfile(
        at absoluteTime: TimeInterval
    ) -> AutoMixSpectralProfile {
        AutoMixSpectralProfile(
            low:
                value(
                    in: lowFrequencyRatios,
                    at: absoluteTime
                ),
            mid:
                value(
                    in: midFrequencyRatios,
                    at: absoluteTime
                ),
            high:
                value(
                    in: highFrequencyRatios,
                    at: absoluteTime
                )
        )
    }

    func novelty(
        at absoluteTime: TimeInterval
    ) -> Float {
        value(
            in: spectralNovelty,
            at: absoluteTime
        )
    }

    func beatActivation(
        at absoluteTime: TimeInterval
    ) -> Float {
        value(
            in: modelBeatActivations,
            at: absoluteTime
        )
    }

    func downbeatActivation(
        at absoluteTime: TimeInterval
    ) -> Float {
        value(
            in: modelDownbeatActivations,
            at: absoluteTime
        )
    }

    private func value(
        in values: [Float],
        at absoluteTime: TimeInterval,
        fallback: Float = 0
    ) -> Float {
        let relativeTime = absoluteTime - regionStart
        let frame = Int(
            (relativeTime * 50).rounded()
        )
        guard values.indices.contains(frame) else {
            return fallback
        }
        return values[frame]
    }
}

nonisolated struct BeatNetFeatureStatistics:
    Equatable,
    Sendable
{
    let maximum: Float
    let mean: Float
    let nonzeroValueCount: Int
    let finiteValueCount: Int
    let valueCount: Int

    init(values: [Float]) {
        var maximum: Float = 0
        var sum: Double = 0
        var nonzeroValueCount = 0
        var finiteValueCount = 0

        for value in values where value.isFinite {
            maximum = max(maximum, value)
            sum += Double(value)
            finiteValueCount += 1
            if abs(value) > 0.000_001 {
                nonzeroValueCount += 1
            }
        }

        self.maximum = maximum
        mean =
            finiteValueCount > 0
            ? Float(sum / Double(finiteValueCount))
            : 0
        self.nonzeroValueCount = nonzeroValueCount
        self.finiteValueCount = finiteValueCount
        valueCount = values.count
    }

    init(merging statistics: [Self]) {
        maximum =
            statistics
                .map(\.maximum)
                .max()
                ?? 0
        nonzeroValueCount =
            statistics.reduce(0) {
                $0 + $1.nonzeroValueCount
            }
        finiteValueCount =
            statistics.reduce(0) {
                $0 + $1.finiteValueCount
            }
        valueCount =
            statistics.reduce(0) {
                $0 + $1.valueCount
            }
        let weightedSum =
            statistics.reduce(0.0) {
                $0
                    + Double($1.mean)
                        * Double($1.finiteValueCount)
            }
        mean =
            finiteValueCount > 0
            ? Float(
                weightedSum
                    / Double(finiteValueCount)
            )
            : 0
    }
}

nonisolated struct AutoMixPairAnalysis: Sendable {
    let outgoing: AutoMixTrackAnalysis
    let incoming: AutoMixTrackAnalysis
}

nonisolated enum AutoMixAnalysisError: LocalizedError {
    case modelMissing
    case audioTrackMissing
    case readerCouldNotStart
    case readerFailed(Error?)
    case invalidAudioBuffer
    case invalidModelOutput
    case invalidRemoteResponse

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            L10n.string("ui.error.automix.model_missing")
        case .audioTrackMissing:
            L10n.string("ui.error.automix.no_audio_track")
        case .readerCouldNotStart:
            L10n.string("ui.error.automix.analysis_start_failed")
        case .readerFailed(let error):
            error?.localizedDescription
                ?? L10n.string("ui.error.automix.audio_read_failed")
        case .invalidAudioBuffer:
            L10n.string("ui.error.automix.invalid_decoded_audio")
        case .invalidModelOutput:
            L10n.string("ui.error.automix.invalid_result")
        case .invalidRemoteResponse:
            L10n.string("ui.error.automix.download_failed")
        }
    }
}

actor AutoMixAudioAnalyzer {
    private enum Region: Hashable {
        case head
        case tail(durationMilliseconds: Int)
        case window(startMilliseconds: Int)
    }

    private struct CacheKey: Hashable {
        let songID: Int
        let region: Region
    }

    private struct FullTrackCacheKey: Hashable {
        let songID: Int
        let durationMilliseconds: Int
    }

    private var cachedAnalyses: [CacheKey: AutoMixTrackAnalysis] = [:]
    private var cachedFullTrackAnalyses:
        [FullTrackCacheKey: AutoMixTrackAnalysis] = [:]
    private var stagedSourceURLs: [Int: URL] = [:]
    private var stagedSourceOrder: [Int] = []
    private var model: MLModel?
    private let featureExtractor: BeatNetFeatureExtractor
    private let stagingDirectory: URL

    init() {
        featureExtractor = try! BeatNetFeatureExtractor()
        stagingDirectory =
            FileManager.default.temporaryDirectory
                .appending(
                    path:
                        "\(AppStorageLocations.beatAnalysisDirectoryPrefix)\(UUID().uuidString)",
                    directoryHint: .isDirectory
                )
        try? FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
    }

    deinit {
        try? FileManager.default.removeItem(
            at: stagingDirectory
        )
    }

    func analyzePair(
        outgoing: AutoMixAnalysisRequest,
        incoming: AutoMixAnalysisRequest
    ) async throws -> AutoMixPairAnalysis {
        async let outgoingAnalysis =
            analyzeFullTrack(outgoing)
        async let incomingAnalysis =
            analyzeFullTrack(incoming)
        return AutoMixPairAnalysis(
            outgoing: try await outgoingAnalysis,
            incoming: try await incomingAnalysis
        )
    }

    func analyzeFullTrack(
        _ request: AutoMixAnalysisRequest
    ) async throws -> AutoMixTrackAnalysis {
        let duration = max(request.duration, 0)
        let cacheKey = FullTrackCacheKey(
            songID: request.songID,
            durationMilliseconds: Int(
                (duration * 1_000).rounded()
            )
        )
        if let cached =
            cachedFullTrackAnalyses[cacheKey] {
            return cached
        }

        if !request.source.url.isFileURL {
            _ = try await stagedSourceURL(
                for: request
            )
            try Task.checkCancellation()
        }

        let windowDuration =
            BeatNetFeatureExtractor.windowDuration
        let segmentCount = max(
            Int(
                ceil(
                    max(duration, 0.1)
                        / windowDuration
                )
            ),
            1
        )
        var segments: [AutoMixTrackAnalysis] = []
        segments.reserveCapacity(segmentCount)

        for segmentIndex in 0..<segmentCount {
            try Task.checkCancellation()
            let startTime =
                Double(segmentIndex)
                    * windowDuration
            let region: Region =
                segmentIndex == 0
                ? .head
                : .window(
                    startMilliseconds: Int(
                        (startTime * 1_000)
                            .rounded()
                    )
                )
            segments.append(
                try await analyze(
                    request,
                    region: region
                )
            )
        }

        let analysis = mergeFullTrackSegments(
            segments,
            duration: duration
        )
        cachedFullTrackAnalyses[cacheKey] =
            analysis
        return analysis
    }

    func clearCache() {
        cachedAnalyses.removeAll()
        cachedFullTrackAnalyses.removeAll()
        stagedSourceURLs.removeAll()
        stagedSourceOrder.removeAll()
        try? FileManager.default.removeItem(
            at: stagingDirectory
        )
        try? FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
    }

    private func analyze(
        _ request: AutoMixAnalysisRequest,
        region: Region
    ) async throws -> AutoMixTrackAnalysis {
        let cacheKey = CacheKey(
            songID: request.songID,
            region: region
        )
        if let cached = cachedAnalyses[cacheKey] {
            return cached
        }

        let regionStart: TimeInterval
        switch region {
        case .head:
            regionStart = 0
        case .tail:
            regionStart = max(
                request.duration
                    - BeatNetFeatureExtractor.windowDuration,
                0
            )
        case .window(let startMilliseconds):
            regionStart =
                TimeInterval(startMilliseconds)
                    / 1_000
        }
        let samples = try await decodeSamples(
            for: request,
            startTime: regionStart,
            duration: min(
                BeatNetFeatureExtractor.windowDuration,
                max(request.duration - regionStart, 0)
            )
        )
        try Task.checkCancellation()
        let features = featureExtractor.extract(from: samples)
        let activations = try predict(features.values)
        let analysis = BeatNetTemporalDecoder.decode(
            activations: activations,
            energy: features.normalizedEnergy,
            loudnessDecibels:
                features.loudnessDecibels,
            lowFrequencyRatios:
                features.lowFrequencyRatios,
            midFrequencyRatios:
                features.midFrequencyRatios,
            highFrequencyRatios:
                features.highFrequencyRatios,
            spectralNovelty:
                features.spectralNovelty,
            featureStatistics:
                BeatNetFeatureStatistics(
                    values: features.values
                ),
            finalAllZeroSegmentCount:
                outputIsAllZero(activations)
                    ? 1
                    : 0,
            analyzedSegmentCount: 1,
            regionStart: regionStart
        )
        cachedAnalyses[cacheKey] = analysis
        return analysis
    }

    private func mergeFullTrackSegments(
        _ segments: [AutoMixTrackAnalysis],
        duration: TimeInterval
    ) -> AutoMixTrackAnalysis {
        let framesPerSecond = 50.0
        let frameCount = max(
            Int(
                ceil(
                    max(duration, 0.02)
                        * framesPerSecond
                )
            ),
            1
        )
        var energy = Array(
            repeating: Float.zero,
            count: frameCount
        )
        var loudnessDecibels = Array(
            repeating: Float(-120),
            count: frameCount
        )
        var lowFrequencyRatios = energy
        var midFrequencyRatios = energy
        var highFrequencyRatios = energy
        var spectralNovelty = energy
        var modelBeatActivations = energy
        var modelDownbeatActivations = energy
        var beats: [TimeInterval] = []
        var downbeats: [TimeInterval] = []
        var bpmWeightedSum = 0.0
        var bpmWeight = 0.0
        var confidenceWeightedSum = 0.0
        var confidenceWeight = 0.0

        for segment in segments {
            let startFrame = Int(
                (
                    segment.regionStart
                        * framesPerSecond
                ).rounded()
            )
            copy(
                segment.normalizedEnergy,
                into: &energy,
                at: startFrame
            )
            copy(
                segment.loudnessDecibels,
                into: &loudnessDecibels,
                at: startFrame
            )
            copy(
                segment.lowFrequencyRatios,
                into: &lowFrequencyRatios,
                at: startFrame
            )
            copy(
                segment.midFrequencyRatios,
                into: &midFrequencyRatios,
                at: startFrame
            )
            copy(
                segment.highFrequencyRatios,
                into: &highFrequencyRatios,
                at: startFrame
            )
            copy(
                segment.spectralNovelty,
                into: &spectralNovelty,
                at: startFrame
            )
            copy(
                segment.modelBeatActivations,
                into: &modelBeatActivations,
                at: startFrame
            )
            copy(
                segment.modelDownbeatActivations,
                into: &modelDownbeatActivations,
                at: startFrame
            )
            let segmentEnd = min(
                segment.regionStart
                    + BeatNetFeatureExtractor
                        .windowDuration,
                duration
            )
            beats.append(
                contentsOf:
                    segment.beats.filter {
                        $0 >= segment.regionStart
                            && $0 < segmentEnd
                    }
            )
            downbeats.append(
                contentsOf:
                    segment.downbeats.filter {
                        $0 >= segment.regionStart
                            && $0 < segmentEnd
                    }
            )

            let coveredDuration = max(
                segmentEnd - segment.regionStart,
                0
            )
            let confidence =
                min(max(segment.confidence, 0), 1)
            let localBPMWeight =
                coveredDuration
                    * (0.25 + confidence * 0.75)
            bpmWeightedSum +=
                segment.bpm * localBPMWeight
            bpmWeight += localBPMWeight
            confidenceWeightedSum +=
                confidence * coveredDuration
            confidenceWeight += coveredDuration
        }

        return AutoMixTrackAnalysis(
            bpm:
                bpmWeight > 0
                ? bpmWeightedSum / bpmWeight
                : segments.first?.bpm ?? 120,
            confidence:
                confidenceWeight > 0
                ? confidenceWeightedSum
                    / confidenceWeight
                : segments.first?.confidence ?? 0,
            beats: beats.sorted(),
            downbeats: downbeats.sorted(),
            regionStart: 0,
            normalizedEnergy: energy,
            loudnessDecibels:
                loudnessDecibels,
            lowFrequencyRatios:
                lowFrequencyRatios,
            midFrequencyRatios:
                midFrequencyRatios,
            highFrequencyRatios:
                highFrequencyRatios,
            spectralNovelty:
                spectralNovelty,
            modelBeatActivations:
                modelBeatActivations,
            modelDownbeatActivations:
                modelDownbeatActivations,
            featureStatistics:
                BeatNetFeatureStatistics(
                    merging:
                        segments.map(
                            \.featureStatistics
                        )
                ),
            finalAllZeroSegmentCount:
                segments.reduce(0) {
                    $0
                        + $1
                            .finalAllZeroSegmentCount
                },
            analyzedSegmentCount:
                segments.reduce(0) {
                    $0 + $1.analyzedSegmentCount
                }
        )
    }

    private func copy(
        _ source: [Float],
        into destination: inout [Float],
        at startIndex: Int
    ) {
        guard startIndex >= 0,
              startIndex < destination.count else {
            return
        }
        let count = min(
            source.count,
            destination.count - startIndex
        )
        guard count > 0 else {
            return
        }
        destination.replaceSubrange(
            startIndex..<(startIndex + count),
            with: source.prefix(count)
        )
    }

    private func loadModel() throws -> MLModel {
        if let model {
            return model
        }
        guard let modelURL = Bundle.main.url(
            forResource: "BeatNetBDA",
            withExtension: "mlmodelc"
        ) else {
            throw AutoMixAnalysisError.modelMissing
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        let loadedModel = try MLModel(
            contentsOf: modelURL,
            configuration: configuration
        )
        model = loadedModel
        return loadedModel
    }

    private func predict(
        _ features: [Float]
    ) throws -> [
        (beat: Float, downbeat: Float)
    ] {
        let expectedCount =
            BeatNetFeatureExtractor.frameCount
                * BeatNetFeatureExtractor.featureCount
        guard features.count == expectedCount else {
            throw AutoMixAnalysisError.invalidModelOutput
        }
        let input = try MLMultiArray(
            shape: [
                1,
                NSNumber(value: BeatNetFeatureExtractor.frameCount),
                NSNumber(value: BeatNetFeatureExtractor.featureCount),
            ],
            dataType: .float32
        )
        let inputPointer = input.dataPointer.bindMemory(
            to: Float.self,
            capacity: expectedCount
        )
        features.withUnsafeBufferPointer { featuresPointer in
            guard let baseAddress = featuresPointer.baseAddress else {
                return
            }
            inputPointer.update(
                from: baseAddress,
                count: expectedCount
            )
        }
        let provider = try MLDictionaryFeatureProvider(
            dictionary: ["features": input]
        )
        return try activations(
            from: loadModel(),
            provider: provider
        )
    }

    private func activations(
        from model: MLModel,
        provider: MLFeatureProvider
    ) throws -> [
        (beat: Float, downbeat: Float)
    ] {
        let prediction = try model.prediction(
            from: provider
        )
        guard let output = prediction.featureValue(
            for: "activations"
        )?.multiArrayValue,
              output.shape.map(\.intValue)
                == [
                    1,
                    BeatNetFeatureExtractor
                        .frameCount,
                    2,
                ] else {
            throw AutoMixAnalysisError.invalidModelOutput
        }
        var activations: [(Float, Float)] = []
        activations.reserveCapacity(
            BeatNetFeatureExtractor.frameCount
        )
        for frame in 0..<BeatNetFeatureExtractor.frameCount {
            let beat = output[
                [
                    0,
                    NSNumber(value: frame),
                    0,
                ]
            ].floatValue
            let downbeat = output[
                [
                    0,
                    NSNumber(value: frame),
                    1,
                ]
            ].floatValue
            activations.append((beat, downbeat))
        }
        return activations
    }

    private func outputIsAllZero(
        _ activations: [
            (beat: Float, downbeat: Float)
        ]
    ) -> Bool {
        !activations.contains { activation in
            (
                activation.beat.isFinite
                    && activation.beat > 0
            )
                || (
                    activation.downbeat.isFinite
                        && activation.downbeat > 0
                )
        }
    }

    private func decodeSamples(
        for request: AutoMixAnalysisRequest,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> [Float] {
        if let stagedURL =
            stagedSourceURLs[request.songID],
           FileManager.default.fileExists(
               atPath: stagedURL.path
           ) {
            return try await decodeSamples(
                from: stagedURL,
                startTime: startTime,
                duration: duration
            )
        }

        do {
            return try await decodeSamples(
                from: request.source.url,
                startTime: startTime,
                duration: duration
            )
        } catch {
            try Task.checkCancellation()
            guard !request.source.url.isFileURL else {
                throw error
            }

            let stagedURL = try await stagedSourceURL(
                for: request
            )
            try Task.checkCancellation()
            return try await decodeSamples(
                from: stagedURL,
                startTime: startTime,
                duration: duration
            )
        }
    }

    private func stagedSourceURL(
        for request: AutoMixAnalysisRequest
    ) async throws -> URL {
        if let cachedURL =
            stagedSourceURLs[request.songID],
           FileManager.default.fileExists(
               atPath: cachedURL.path
           ) {
            return cachedURL
        }

        let temporaryURL: URL
        let response: URLResponse
        do {
            (temporaryURL, response) =
                try await URLSession.shared.download(
                    from: request.source.url
                )
        } catch let error as URLError
            where error.code == .cancelled {
            throw CancellationError()
        }
        try Task.checkCancellation()

        if let httpResponse =
            response as? HTTPURLResponse,
           !(200..<300).contains(
               httpResponse.statusCode
           ) {
            throw AutoMixAnalysisError
                .invalidRemoteResponse
        }

        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
        let baseURL = stagingDirectory.appending(
            path:
                "\(request.songID)-\(UUID().uuidString)",
            directoryHint: .notDirectory
        )
        let sourceExtension =
            request.source.url.pathExtension
        let format = request.source.format ?? ""
        let pathExtension = sourceExtension.isEmpty
            ? format
            : sourceExtension
        let destinationURL = pathExtension.isEmpty
            ? baseURL
            : baseURL.appendingPathExtension(
                pathExtension
            )

        do {
            try FileManager.default.moveItem(
                at: temporaryURL,
                to: destinationURL
            )
            try Task.checkCancellation()
        } catch {
            try? FileManager.default.removeItem(
                at: destinationURL
            )
            throw error
        }

        stagedSourceURLs[request.songID] =
            destinationURL
        stagedSourceOrder.removeAll {
            $0 == request.songID
        }
        stagedSourceOrder.append(request.songID)
        removeExpiredStagedSources()
        return destinationURL
    }

    private func removeExpiredStagedSources() {
        while stagedSourceOrder.count > 3 {
            let songID =
                stagedSourceOrder.removeFirst()
            guard let url =
                stagedSourceURLs.removeValue(
                    forKey: songID
                ) else {
                continue
            }
            try? FileManager.default.removeItem(
                at: url
            )
        }
    }

    private func decodeSamples(
        from url: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(
            withMediaType: .audio
        )
        guard let track = tracks.first else {
            throw AutoMixAnalysisError.audioTrackMissing
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(
                seconds: max(startTime, 0),
                preferredTimescale: 600
            ),
            duration: CMTime(
                seconds: max(duration, 0.1),
                preferredTimescale: 600
            )
        )
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey:
                    Double(BeatNetFeatureExtractor.sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw AutoMixAnalysisError.invalidAudioBuffer
        }
        reader.add(output)
        guard reader.startReading() else {
            throw AutoMixAnalysisError.readerCouldNotStart
        }
        defer {
            if reader.status == .reading {
                reader.cancelReading()
            }
        }

        let maximumSampleCount =
            BeatNetFeatureExtractor.sampleRate
                * Int(BeatNetFeatureExtractor.windowDuration)
        var samples: [Float] = []
        samples.reserveCapacity(maximumSampleCount)
        while reader.status == .reading,
              samples.count < maximumSampleCount {
            try Task.checkCancellation()
            guard let sampleBuffer =
                output.copyNextSampleBuffer() else {
                break
            }
            defer {
                CMSampleBufferInvalidate(sampleBuffer)
            }
            guard let blockBuffer =
                CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }
            var lengthAtOffset = 0
            var totalLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            guard status == kCMBlockBufferNoErr,
                  let dataPointer else {
                throw AutoMixAnalysisError.invalidAudioBuffer
            }
            let availableCount =
                totalLength / MemoryLayout<Float>.stride
            let remainingCount =
                maximumSampleCount - samples.count
            let count = min(availableCount, remainingCount)
            let floats = UnsafeRawPointer(dataPointer)
                .assumingMemoryBound(to: Float.self)
            samples.append(
                contentsOf: UnsafeBufferPointer(
                    start: floats,
                    count: count
                )
            )
        }
        try Task.checkCancellation()
        if reader.status == .cancelled {
            throw CancellationError()
        }
        if reader.status == .failed {
            throw AutoMixAnalysisError.readerFailed(
                reader.error
            )
        }
        guard !samples.isEmpty else {
            throw AutoMixAnalysisError.invalidAudioBuffer
        }
        return samples
    }
}

nonisolated private enum BeatNetTemporalDecoder {
    private static let framesPerSecond = 50.0

    static func decode(
        activations: [(beat: Float, downbeat: Float)],
        energy: [Float],
        loudnessDecibels: [Float],
        lowFrequencyRatios: [Float],
        midFrequencyRatios: [Float],
        highFrequencyRatios: [Float],
        spectralNovelty: [Float],
        featureStatistics: BeatNetFeatureStatistics,
        finalAllZeroSegmentCount: Int,
        analyzedSegmentCount: Int,
        regionStart: TimeInterval
    ) -> AutoMixTrackAnalysis {
        let beatActivations = activations.map(\.beat)
        let downbeatActivations = activations.map(\.downbeat)
        let lagRange = 12...55
        let correlationScores = lagRange.map { lag in
            autocorrelation(
                values: beatActivations,
                lag: lag
            )
        }
        var bestLag = lagRange.lowerBound
        var bestScore: Float = -.infinity
        for (offset, score) in correlationScores.enumerated()
        where score > bestScore {
            bestScore = score
            bestLag = lagRange.lowerBound + offset
        }
        bestLag = correctedLag(
            bestLag,
            scores: correlationScores,
            lagRange: lagRange
        )

        let phase = strongestPhase(
            values: beatActivations,
            period: bestLag
        )
        let beatFrames = refinedBeatFrames(
            values: beatActivations,
            phase: phase,
            period: bestLag
        )
        let downbeatPhase = strongestDownbeatPhase(
            values: downbeatActivations,
            beatFrames: beatFrames
        )
        let downbeatFrames = beatFrames.enumerated()
            .compactMap { index, frame in
                index % 4 == downbeatPhase ? frame : nil
            }
        let confidence = confidence(
            beatActivations: beatActivations,
            downbeatActivations: downbeatActivations,
            beatFrames: beatFrames,
            downbeatFrames: downbeatFrames,
            correlationScore: bestScore
        )
        return AutoMixTrackAnalysis(
            bpm: framesPerSecond * 60 / Double(bestLag),
            confidence: confidence,
            beats: beatFrames.map {
                regionStart + Double($0) / framesPerSecond
            },
            downbeats: downbeatFrames.map {
                regionStart + Double($0) / framesPerSecond
            },
            regionStart: regionStart,
            normalizedEnergy: energy,
            loudnessDecibels:
                loudnessDecibels,
            lowFrequencyRatios:
                lowFrequencyRatios,
            midFrequencyRatios:
                midFrequencyRatios,
            highFrequencyRatios:
                highFrequencyRatios,
            spectralNovelty:
                spectralNovelty,
            modelBeatActivations:
                beatActivations,
            modelDownbeatActivations:
                downbeatActivations,
            featureStatistics:
                featureStatistics,
            finalAllZeroSegmentCount:
                finalAllZeroSegmentCount,
            analyzedSegmentCount:
                analyzedSegmentCount
        )
    }

    private static func autocorrelation(
        values: [Float],
        lag: Int
    ) -> Float {
        guard values.count > lag else { return 0 }
        var numerator: Float = 0
        var leftEnergy: Float = 0
        var rightEnergy: Float = 0
        for index in lag..<values.count {
            let left = values[index]
            let right = values[index - lag]
            numerator += left * right
            leftEnergy += left * left
            rightEnergy += right * right
        }
        return numerator
            / max(
                sqrt(leftEnergy * rightEnergy),
                .leastNonzeroMagnitude
            )
    }

    private static func correctedLag(
        _ lag: Int,
        scores: [Float],
        lagRange: ClosedRange<Int>
    ) -> Int {
        let bpm = framesPerSecond * 60 / Double(lag)
        if bpm > 180 {
            let slowerLag = lag * 2
            if lagRange.contains(slowerLag),
               score(
                   for: slowerLag,
                   scores: scores,
                   lagRange: lagRange
               ) >= score(
                   for: lag,
                   scores: scores,
                   lagRange: lagRange
               ) * 0.86 {
                return slowerLag
            }
        } else if bpm < 75 {
            let fasterLag = lag / 2
            if lagRange.contains(fasterLag),
               score(
                   for: fasterLag,
                   scores: scores,
                   lagRange: lagRange
               ) >= score(
                   for: lag,
                   scores: scores,
                   lagRange: lagRange
               ) * 0.9 {
                return fasterLag
            }
        }
        return lag
    }

    private static func score(
        for lag: Int,
        scores: [Float],
        lagRange: ClosedRange<Int>
    ) -> Float {
        scores[lag - lagRange.lowerBound]
    }

    private static func strongestPhase(
        values: [Float],
        period: Int
    ) -> Int {
        var bestPhase = 0
        var bestScore: Float = -.infinity
        for phase in 0..<period {
            var score: Float = 0
            var frame = phase
            while frame < values.count {
                score += values[frame]
                frame += period
            }
            if score > bestScore {
                bestScore = score
                bestPhase = phase
            }
        }
        return bestPhase
    }

    private static func refinedBeatFrames(
        values: [Float],
        phase: Int,
        period: Int
    ) -> [Int] {
        var frames: [Int] = []
        var nominalFrame = phase
        while nominalFrame < values.count {
            let lowerBound = max(nominalFrame - 2, 0)
            let upperBound = min(
                nominalFrame + 2,
                values.count - 1
            )
            let range = lowerBound...upperBound
            if let frame = range.max(
                by: { values[$0] < values[$1] }
            ), frames.last != frame {
                frames.append(frame)
            }
            nominalFrame += period
        }
        return frames
    }

    private static func strongestDownbeatPhase(
        values: [Float],
        beatFrames: [Int]
    ) -> Int {
        guard !beatFrames.isEmpty else { return 0 }
        return (0..<4).max { left, right in
            let leftScore = stride(
                from: left,
                to: beatFrames.count,
                by: 4
            ).reduce(Float.zero) {
                $0 + values[beatFrames[$1]]
            }
            let rightScore = stride(
                from: right,
                to: beatFrames.count,
                by: 4
            ).reduce(Float.zero) {
                $0 + values[beatFrames[$1]]
            }
            return leftScore < rightScore
        } ?? 0
    }

    private static func confidence(
        beatActivations: [Float],
        downbeatActivations: [Float],
        beatFrames: [Int],
        downbeatFrames: [Int],
        correlationScore: Float
    ) -> Double {
        let background = beatActivations.reduce(0, +)
            / Float(max(beatActivations.count, 1))
        let beatMean = beatFrames.reduce(Float.zero) {
            $0 + beatActivations[$1]
        } / Float(max(beatFrames.count, 1))
        let downbeatMean = downbeatFrames.reduce(Float.zero) {
            $0 + downbeatActivations[$1]
        } / Float(max(downbeatFrames.count, 1))
        let contrast = max(
            (beatMean - background)
                / max(1 - background, 0.01),
            0
        )
        let value =
            contrast * 0.5
            + max(correlationScore, 0) * 0.35
            + downbeatMean * 0.15
        return Double(min(max(value, 0), 1))
    }
}
