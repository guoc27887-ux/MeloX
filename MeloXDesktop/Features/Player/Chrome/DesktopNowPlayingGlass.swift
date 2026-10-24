import SwiftUI

struct DesktopNowPlayingGlassCapsule: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                .clear.interactive(),
                in: .capsule
            )
        } else {
            content
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.32), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
        }
    }
}

struct DesktopNowPlayingCircularGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 28, height: 28)
            .foregroundStyle(.white)
            .background(.white.opacity(0.12), in: .circle)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            }
            .contentShape(.circle)
    }
}
