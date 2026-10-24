import SwiftUI

struct LiveActivityCompactText: View, Animatable {
    let text: String
    let pointSize: Double
    var travelDistance: CGFloat

    var animatableData: CGFloat {
        get { travelDistance }
        set { travelDistance = newValue }
    }

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .nonLinear,
            rendersAsynchronously: false
        ) { context, size in
            let resolvedText = context.resolve(
                Text(text)
                    .font(
                        .system(
                            size: pointSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
            )
            context.draw(
                resolvedText,
                at: CGPoint(
                    x: -travelDistance,
                    y: size.height / 2
                ),
                anchor: .leading
            )
        }
        .accessibilityLabel(text)
    }
}
