import SwiftUI

enum AppleMusicBackdropShader {
    static func rotation(
        size: CGSize,
        time: TimeInterval,
        spectrum: PlaybackAudioSpectrumSnapshot,
        saturation: Double,
        blackScrimAlpha: Double,
        motionIntensity: Double
    ) -> Shader {
        ShaderLibrary.appleMusicBackdropRotation(
            .float2(size),
            .float(time),
            .float4(
                spectrum.low,
                spectrum.mid,
                spectrum.high,
                spectrum.overall
            ),
            .float(saturation),
            .float(blackScrimAlpha),
            .float(motionIntensity)
        )
    }

    static func pinch(
        size: CGSize,
        time: TimeInterval,
        pinchMix: Float,
        meshIndex: Int
    ) -> Shader {
        ShaderLibrary.appleMusicBackdropPinch(
            .float2(size),
            .float(time),
            .float(pinchMix),
            .float(Float(meshIndex))
        )
    }
}
