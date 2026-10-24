import Accelerate
import Foundation

nonisolated struct BeatNetFeatures: Sendable {
    let values: [Float]
    let normalizedEnergy: [Float]
    let loudnessDecibels: [Float]
    let lowFrequencyRatios: [Float]
    let midFrequencyRatios: [Float]
    let highFrequencyRatios: [Float]
    let spectralNovelty: [Float]
}

nonisolated enum BeatNetFeatureExtractorError: Error {
    case unableToCreateFFT
}

nonisolated final class BeatNetFeatureExtractor {
    static let sampleRate = 22_050
    static let frameCount = 1_600
    static let featureCount = 272
    static let windowDuration: TimeInterval = 32

    private static let frameSize = 1_411
    private static let hopSize = 441
    private static let fftSize = 2_048
    private static let fftBinCount = fftSize / 2
    private static let bandCount = featureCount / 2

    private struct WeightedBin {
        let index: Int
        let weight: Float
    }

    private let fftSetup: FFTSetup
    private let window: [Float]
    private let filters: [[WeightedBin]]
    private let filterCenterFrequencies: [Double]

    init() throws {
        let log2Size = vDSP_Length(log2(Float(Self.fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(
            log2Size,
            FFTRadix(kFFTRadix2)
        ) else {
            throw BeatNetFeatureExtractorError.unableToCreateFFT
        }
        self.fftSetup = fftSetup
        window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: Self.frameSize,
            isHalfWindow: false
        )
        let filterBank = Self.makeFilters()
        filters = filterBank.filters
        filterCenterFrequencies =
            filterBank.centerFrequencies
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func extract(from inputSamples: [Float]) -> BeatNetFeatures {
        let requiredSamples =
            Self.sampleRate * Int(Self.windowDuration)
        var samples = Array(inputSamples.prefix(requiredSamples))
        if samples.count < requiredSamples {
            samples.append(
                contentsOf: repeatElement(
                    0,
                    count: requiredSamples - samples.count
                )
            )
        }

        var featureValues = [Float](
            repeating: 0,
            count: Self.frameCount * Self.featureCount
        )
        var rawEnergy = [Float](
            repeating: 0,
            count: Self.frameCount
        )
        var lowFrequencyRatios = rawEnergy
        var midFrequencyRatios = rawEnergy
        var highFrequencyRatios = rawEnergy
        var rawSpectralFlux = rawEnergy
        var previousBands = [Float](
            repeating: 0,
            count: Self.bandCount
        )
        var fftInput = [Float](
            repeating: 0,
            count: Self.fftSize
        )
        var real = [Float](
            repeating: 0,
            count: Self.fftBinCount
        )
        var imaginary = [Float](
            repeating: 0,
            count: Self.fftBinCount
        )
        var magnitudes = [Float](
            repeating: 0,
            count: Self.fftBinCount
        )

        for frameIndex in 0..<Self.frameCount {
            fftInput.withUnsafeMutableBufferPointer { buffer in
                buffer.initialize(repeating: 0)
            }
            let referenceSample = frameIndex * Self.hopSize
            let startSample =
                referenceSample - Self.frameSize / 2
            var energy: Float = 0
            for windowIndex in 0..<Self.frameSize {
                let sampleIndex = startSample + windowIndex
                let sample = samples.indices.contains(sampleIndex)
                    ? samples[sampleIndex]
                    : 0
                let windowedSample = sample * window[windowIndex]
                fftInput[windowIndex] = windowedSample
                energy += sample * sample
            }
            rawEnergy[frameIndex] =
                sqrt(energy / Float(Self.frameSize))

            transform(
                input: &fftInput,
                real: &real,
                imaginary: &imaginary,
                magnitudes: &magnitudes
            )

            let featureOffset =
                frameIndex * Self.featureCount
            var lowMagnitude: Float = 0
            var midMagnitude: Float = 0
            var highMagnitude: Float = 0
            var lowBandCount = 0
            var midBandCount = 0
            var highBandCount = 0
            var spectralFlux: Float = 0
            for bandIndex in 0..<Self.bandCount {
                var filteredMagnitude: Float = 0
                for weightedBin in filters[bandIndex] {
                    filteredMagnitude +=
                        magnitudes[weightedBin.index]
                        * weightedBin.weight
                }
                let logarithmicMagnitude =
                    log10f(filteredMagnitude + 1)
                let positiveDelta = max(
                    logarithmicMagnitude
                        - previousBands[bandIndex],
                    0
                )
                featureValues[featureOffset + bandIndex] =
                    logarithmicMagnitude
                featureValues[
                    featureOffset
                        + Self.bandCount
                        + bandIndex
                ] = positiveDelta
                previousBands[bandIndex] =
                    logarithmicMagnitude
                spectralFlux += positiveDelta

                switch filterCenterFrequencies[bandIndex] {
                case ..<250:
                    lowMagnitude += logarithmicMagnitude
                    lowBandCount += 1
                case 250..<4_000:
                    midMagnitude += logarithmicMagnitude
                    midBandCount += 1
                default:
                    highMagnitude += logarithmicMagnitude
                    highBandCount += 1
                }
            }

            let lowAverage =
                lowMagnitude
                    / Float(max(lowBandCount, 1))
            let midAverage =
                midMagnitude
                    / Float(max(midBandCount, 1))
            let highAverage =
                highMagnitude
                    / Float(max(highBandCount, 1))
            let spectralTotal = max(
                lowAverage + midAverage + highAverage,
                .leastNonzeroMagnitude
            )
            lowFrequencyRatios[frameIndex] =
                lowAverage / spectralTotal
            midFrequencyRatios[frameIndex] =
                midAverage / spectralTotal
            highFrequencyRatios[frameIndex] =
                highAverage / spectralTotal
            rawSpectralFlux[frameIndex] =
                frameIndex == 0
                ? 0
                : spectralFlux
        }

        let normalizedEnergy =
            Self.normalizeEnergy(rawEnergy)
        return BeatNetFeatures(
            values: featureValues,
            normalizedEnergy: normalizedEnergy,
            loudnessDecibels:
                rawEnergy.map(Self.decibels),
            lowFrequencyRatios:
                lowFrequencyRatios,
            midFrequencyRatios:
                midFrequencyRatios,
            highFrequencyRatios:
                highFrequencyRatios,
            spectralNovelty:
                Self.makeSpectralNovelty(
                    spectralFlux:
                        rawSpectralFlux,
                    normalizedEnergy:
                        normalizedEnergy
                )
        )
    }

    private func transform(
        input: inout [Float],
        real: inout [Float],
        imaginary: inout [Float],
        magnitudes: inout [Float]
    ) {
        let log2Size = vDSP_Length(log2(Float(Self.fftSize)))
        input.withUnsafeMutableBufferPointer { inputBuffer in
            real.withUnsafeMutableBufferPointer { realBuffer in
                imaginary.withUnsafeMutableBufferPointer {
                    imaginaryBuffer in
                    guard let inputBase = inputBuffer.baseAddress,
                          let realBase = realBuffer.baseAddress,
                          let imaginaryBase =
                              imaginaryBuffer.baseAddress else {
                        return
                    }
                    var split = DSPSplitComplex(
                        realp: realBase,
                        imagp: imaginaryBase
                    )
                    inputBase.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: Self.fftBinCount
                    ) { complexInput in
                        vDSP_ctoz(
                            complexInput,
                            2,
                            &split,
                            1,
                            vDSP_Length(Self.fftBinCount)
                        )
                    }
                    vDSP_fft_zrip(
                        fftSetup,
                        &split,
                        1,
                        log2Size,
                        FFTDirection(FFT_FORWARD)
                    )
                    vDSP_zvabs(
                        &split,
                        1,
                        &magnitudes,
                        1,
                        vDSP_Length(Self.fftBinCount)
                    )
                }
            }
        }

        var scale: Float = 0.5
        vDSP_vsmul(
            magnitudes,
            1,
            &scale,
            &magnitudes,
            1,
            vDSP_Length(magnitudes.count)
        )
        magnitudes[0] = abs(real[0]) * scale
    }

    private static func makeFilters() -> (
        filters: [[WeightedBin]],
        centerFrequencies: [Double]
    ) {
        let originalBinCount = 705
        let originalFFTSize = originalBinCount * 2
        let originalBinSpacing =
            Double(sampleRate) / Double(originalFFTSize)
        let left = Int(
            floor(log2(30.0 / 440.0) * 24)
        )
        let right = Int(
            ceil(log2(17_000.0 / 440.0) * 24)
        )
        let centerFrequencies = (left..<right)
            .map { exponent in
                440 * pow(
                    2,
                    Double(exponent) / 24
                )
            }
            .filter { $0 >= 30 && $0 <= 17_000 }
        var originalBins: [Int] = []
        for frequency in centerFrequencies {
            let bin = min(
                max(
                    Int(
                        (frequency / originalBinSpacing)
                            .rounded()
                    ),
                    1
                ),
                originalBinCount - 1
            )
            if originalBins.last != bin {
                originalBins.append(bin)
            }
        }

        let fftBinSpacing =
            Double(sampleRate) / Double(fftSize)
        var filters: [[WeightedBin]] = []
        var filterCenterFrequencies: [Double] = []
        for index in 0..<(originalBins.count - 2) {
            let originalStart = originalBins[index]
            let originalCenter = originalBins[index + 1]
            let originalStop = originalBins[index + 2]
            let start = Int(
                (
                    Double(originalStart)
                        * originalBinSpacing
                        / fftBinSpacing
                ).rounded()
            )
            let center = Int(
                (
                    Double(originalCenter)
                        * originalBinSpacing
                        / fftBinSpacing
                ).rounded()
            )
            let stop = Int(
                (
                    Double(originalStop)
                        * originalBinSpacing
                        / fftBinSpacing
                ).rounded()
            )
            var weights: [WeightedBin] = []
            for bin in start..<stop where bin < fftBinCount {
                let value: Float
                if bin < center {
                    value = Float(bin - start)
                        / Float(max(center - start, 1))
                } else {
                    value = Float(stop - bin)
                        / Float(max(stop - center, 1))
                }
                if value > 0 {
                    weights.append(
                        WeightedBin(
                            index: bin,
                            weight: value
                        )
                    )
                }
            }
            let weightSum = weights.reduce(0) {
                $0 + $1.weight
            }
            filters.append(
                weights.map {
                    WeightedBin(
                        index: $0.index,
                        weight: $0.weight
                            / max(weightSum, .leastNonzeroMagnitude)
                    )
                }
            )
            filterCenterFrequencies.append(
                Double(originalCenter)
                    * originalBinSpacing
            )
        }
        precondition(filters.count == bandCount)
        precondition(
            filterCenterFrequencies.count
                == bandCount
        )
        return (
            filters,
            filterCenterFrequencies
        )
    }

    private static func makeSpectralNovelty(
        spectralFlux: [Float],
        normalizedEnergy: [Float]
    ) -> [Float] {
        let normalizedFlux =
            normalizeEnergy(spectralFlux)
        let smoothedEnergy = movingAverage(
            normalizedEnergy,
            radius: 10
        )
        let comparisonOffset = 25
        let combined = normalizedFlux.indices.map {
            index in
            let previousIndex = max(
                index - comparisonOffset,
                0
            )
            let energyChange = abs(
                smoothedEnergy[index]
                    - smoothedEnergy[previousIndex]
            )
            return normalizedFlux[index] * 0.72
                + energyChange * 0.28
        }
        return normalizeEnergy(combined)
    }

    private static func movingAverage(
        _ values: [Float],
        radius: Int
    ) -> [Float] {
        guard !values.isEmpty else { return [] }
        var prefix = [Float](
            repeating: 0,
            count: values.count + 1
        )
        for index in values.indices {
            prefix[index + 1] =
                prefix[index] + values[index]
        }
        return values.indices.map { index in
            let lowerBound = max(index - radius, 0)
            let upperBound = min(
                index + radius + 1,
                values.count
            )
            return (
                prefix[upperBound]
                    - prefix[lowerBound]
            ) / Float(
                max(upperBound - lowerBound, 1)
            )
        }
    }

    private static func decibels(
        _ rootMeanSquare: Float
    ) -> Float {
        max(
            20
                * log10f(
                    max(
                        rootMeanSquare,
                        0.000_001
                    )
                ),
            -120
        )
    }

    private static func normalizeEnergy(
        _ values: [Float]
    ) -> [Float] {
        let sorted = values.sorted()
        guard let maximum = sorted.last, maximum > 0 else {
            return values
        }
        let highIndex = min(
            Int(Double(sorted.count - 1) * 0.9),
            sorted.count - 1
        )
        let reference = max(
            sorted[highIndex],
            maximum * 0.25,
            .leastNonzeroMagnitude
        )
        return values.map {
            min(max($0 / reference, 0), 1)
        }
    }
}
