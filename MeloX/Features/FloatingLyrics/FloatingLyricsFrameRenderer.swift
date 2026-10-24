import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import SwiftUI
import UIKit

@MainActor
final class FloatingLyricsFrameRenderer {
    static let renderSize = CGSize(width: 960, height: 320)
    static let frameDuration = CMTime(value: 1, timescale: 30)
    static let presentationLeadTime = CMTime(value: 2, timescale: 30)

    private let player: PlayerStore
    private let settings: AppSettings

    init(player: PlayerStore, settings: AppSettings) {
        self.player = player
        self.settings = settings
    }

    func makeSampleBuffer(
        presentation: FloatingLyricsPresentation,
        artworkImage: CGImage?,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        let content = FloatingLyricsContentView(
            presentation: presentation,
            artworkImage: artworkImage
        )
            .frame(
                width: Self.renderSize.width,
                height: Self.renderSize.height
            )
            .environment(player)
            .environment(settings)
            .environment(\.effectiveLyricsRefreshRate, .fps30)

        let imageRenderer = ImageRenderer(content: content)
        imageRenderer.scale = 1
        imageRenderer.proposedSize = ProposedViewSize(Self.renderSize)

        guard let image = imageRenderer.cgImage,
              let pixelBuffer = makePixelBuffer(from: image),
              let formatDescription = makeFormatDescription(
                for: pixelBuffer
              ) else {
            return nil
        }

        var timing = CMSampleTimingInfo(
            duration: Self.frameDuration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else { return nil }

        return sampleBuffer
    }

    private func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = Int(Self.renderSize.width)
        let height = Int(Self.renderSize.height)
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        )
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return pixelBuffer
    }

    private func makeFormatDescription(
        for pixelBuffer: CVPixelBuffer
    ) -> CMVideoFormatDescription? {
        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        return status == noErr ? formatDescription : nil
    }
}
