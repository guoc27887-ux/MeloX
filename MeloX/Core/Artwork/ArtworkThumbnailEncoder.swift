import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ArtworkThumbnailEncoder {
    nonisolated static func jpegData(
        from data: Data,
        maximumPixelSize: Int = 180,
        compressionQuality: Double = 0.82,
        maximumByteCount: Int? = nil
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            return nil
        }

        guard let maximumByteCount else {
            return thumbnail(
                from: source,
                maximumPixelSize: maximumPixelSize
            ).flatMap {
                encodedJPEG(
                    from: $0,
                    compressionQuality: compressionQuality
                )
            }
        }

        let qualities = [
            compressionQuality,
            min(compressionQuality, 0.58),
            min(compressionQuality, 0.44),
            min(compressionQuality, 0.32),
            min(compressionQuality, 0.20),
        ]
        let minimumPixelSize = 24
        var pixelSize = maximumPixelSize
        while pixelSize >= minimumPixelSize {
            guard let thumbnail = thumbnail(
                from: source,
                maximumPixelSize: pixelSize
            ) else {
                return nil
            }
            for quality in qualities {
                guard let encoded = encodedJPEG(
                    from: thumbnail,
                    compressionQuality: quality
                ) else {
                    continue
                }
                if encoded.count <= maximumByteCount {
                    return encoded
                }
            }
            pixelSize = Int(
                (Double(pixelSize) * 0.78).rounded(.down)
            )
        }
        return nil
    }

    nonisolated private static func thumbnail(
        from source: CGImageSource,
        maximumPixelSize: Int
    ) -> CGImage? {
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize:
                maximumPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        )
    }

    nonisolated private static func encodedJPEG(
        from image: CGImage,
        compressionQuality: Double
    ) -> Data? {
        let output = NSMutableData()
        guard let destination =
            CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [
                kCGImageDestinationLossyCompressionQuality:
                    compressionQuality
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }
}
