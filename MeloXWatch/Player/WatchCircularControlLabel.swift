import SwiftUI

struct WatchCircularControlLabel: View {
    let systemImage: String
    let size: CGFloat
    var iconScale: CGFloat = 0.45

    var body: some View {
        if #available(watchOS 26.0, *) {
            symbol
                .frame(width: size, height: size)
                .glassEffect(
                    .regular.interactive(),
                    in: .circle
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color(white: 0.10))
                Circle()
                    .stroke(
                        Color.white.opacity(0.14),
                        lineWidth: 1.5
                    )
                symbol
            }
            .frame(width: size, height: size)
        }
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(
                .system(
                    size: size * iconScale,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)
            .contentShape(.circle)
    }
}
