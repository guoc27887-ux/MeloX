import SwiftUI

/// Keeps the neighbor-blur presentation outside the per-frame lyric
/// TimelineViews so their transactions cannot replace an in-flight blur.
struct DesktopTargetDrivenLyricBlur<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let focusRadius: CGFloat
    let focusAnimation: Animation?
    let isHovered: Bool
    @ViewBuilder let content: Content

    @State private var presentationRadius: CGFloat

    init(
        focusRadius: CGFloat,
        focusAnimation: Animation?,
        isHovered: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.focusRadius = focusRadius
        self.focusAnimation = focusAnimation
        self.isHovered = isHovered
        self.content = content()
        _presentationRadius = State(
            initialValue: isHovered
                ? 0
                : Self.normalized(focusRadius)
        )
    }

    var body: some View {
        content
            .modifier(
                DesktopLyricBlurEffect(radius: presentationRadius)
            )
            .onChange(of: focusRadius) { _, newRadius in
                guard !isHovered else { return }
                updatePresentationRadius(
                    to: newRadius,
                    animation: focusAnimation
                )
            }
            .onChange(of: isHovered) { _, isHovered in
                updatePresentationRadius(
                    to: isHovered ? 0 : focusRadius,
                    animation: .easeOut(duration: 0.16)
                )
            }
            .onChange(of: reduceMotion) { _, _ in
                updatePresentationRadius(
                    to: isHovered ? 0 : focusRadius,
                    animation: nil
                )
            }
    }

    private func updatePresentationRadius(
        to radius: CGFloat,
        animation: Animation?
    ) {
        let normalizedRadius = Self.normalized(radius)
        guard presentationRadius != normalizedRadius else { return }

        guard !reduceMotion, let animation else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                presentationRadius = normalizedRadius
            }
            return
        }

        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = false
        withTransaction(transaction) {
            presentationRadius = normalizedRadius
        }
    }

    private static func normalized(_ radius: CGFloat) -> CGFloat {
        guard radius.isFinite else { return 0 }
        return max(radius, 0)
    }
}

private struct DesktopLyricBlurEffect: AnimatableModifier {
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func body(content: Content) -> some View {
        content.blur(radius: max(radius, 0))
    }
}
