import SwiftUI

struct WatchLyricPressInteraction<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let isSelected: Bool
    let onTap: () -> Void
    private let content: (Double) -> Content

    init(
        isSelected: Bool = false,
        onTap: @escaping () -> Void,
        @ViewBuilder content: @escaping (Double) -> Content
    ) {
        self.isSelected = isSelected
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        Button(action: onTap) {
            WatchLyricPressLabel(content: content)
                .contentShape(.rect)
        }
        .buttonStyle(
            WatchLyricPressButtonStyle(
                isSelected: isSelected,
                reducesMotion: reducesMotion
            )
        )
    }
}

private struct WatchLyricPressLabel<Content: View>: View {
    @Environment(\.watchLyricPressBackgroundProgress)
    private var backgroundProgress

    let content: (Double) -> Content

    var body: some View {
        content(backgroundProgress)
    }
}

private struct WatchLyricPressButtonStyle: ButtonStyle {
    let isSelected: Bool
    let reducesMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        WatchLyricPressButtonStyleBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            isSelected: isSelected,
            reducesMotion: reducesMotion
        )
    }
}

private struct WatchLyricPressButtonStyleBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let isSelected: Bool
    let reducesMotion: Bool

    @State private var scale: CGFloat = 1
    @State private var backgroundProgress = 0.0

    var body: some View {
        label
            .environment(
                \.watchLyricPressBackgroundProgress,
                isSelected ? 1 : backgroundProgress
            )
            .scaleEffect(scale, anchor: .center)
            .onAppear {
                updatePressedState(isPressed, animated: false)
            }
            .onChange(of: isPressed) { _, isPressed in
                updatePressedState(isPressed, animated: true)
            }
            .onChange(of: isSelected) { _, isSelected in
                updateSelectedState(isSelected)
            }
    }

    private func updatePressedState(
        _ isPressed: Bool,
        animated: Bool
    ) {
        guard animated, !reducesMotion else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                scale = isPressed ? WatchLyricPressAnimation.pressedScale : 1
                backgroundProgress =
                    isPressed || isSelected ? 1 : 0
            }
            return
        }

        if isPressed {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                backgroundProgress = 1
            }
            withAnimation(
                .easeInOut(
                    duration: WatchLyricPressAnimation.pressDuration
                )
            ) {
                scale = WatchLyricPressAnimation.pressedScale
            }
        } else {
            withAnimation(
                .easeInOut(
                    duration: WatchLyricPressAnimation.releaseDuration
                )
            ) {
                scale = 1
            }
            guard !isSelected else { return }
            withAnimation(
                .easeIn(
                    duration:
                        WatchLyricPressAnimation
                            .backgroundReleaseDuration
                )
            ) {
                backgroundProgress = 0
            }
        }
    }

    private func updateSelectedState(_ isSelected: Bool) {
        if isSelected {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                backgroundProgress = 1
            }
        } else {
            withAnimation(
                reducesMotion
                    ? nil
                    : .easeInOut(
                        duration:
                            WatchLyricPressAnimation.releaseDuration
                    )
            ) {
                scale = 1
            }
            withAnimation(
                reducesMotion
                    ? nil
                    : .easeIn(
                        duration:
                            WatchLyricPressAnimation
                                .backgroundReleaseDuration
                    )
            ) {
                backgroundProgress = 0
            }
        }
    }
}

private enum WatchLyricPressAnimation {
    static let pressedScale: CGFloat = 0.96
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.38
    static let backgroundReleaseDuration: TimeInterval = 0.28
}

private struct WatchLyricPressBackgroundProgressKey:
    EnvironmentKey
{
    static let defaultValue = 0.0
}

private extension EnvironmentValues {
    var watchLyricPressBackgroundProgress: Double {
        get { self[WatchLyricPressBackgroundProgressKey.self] }
        set {
            self[WatchLyricPressBackgroundProgressKey.self] =
                newValue
        }
    }
}
