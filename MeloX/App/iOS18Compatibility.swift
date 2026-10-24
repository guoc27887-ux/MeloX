import SwiftUI
import UIKit

/// iOS 18 compatibility shims for APIs introduced in iOS 26 (Liquid Glass and
/// friends). On iOS 26 the original API is used unchanged; on iOS 18 each shim
/// falls back to the closest pre-26 equivalent (plain frosted material, bordered
/// buttons, or simply omitting the modifier). Nothing here changes behavior on
/// iOS 26.

/// Drop-in replacement for `GlassEffectContainer`: on iOS 18 the container is
/// a no-op and its content renders directly.
struct CompatGlassEffectContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// Replacement for `.glassEffect(.clear.interactive(), in: shape)`: frosted
    /// material in the same shape on iOS 18.
    @ViewBuilder
    func compatGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.clear.interactive(), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// Replacement for `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`:
    /// bordered styles on iOS 18 (border shape and control size modifiers on
    /// the call site keep working with both).
    @ViewBuilder
    func compatGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }

    /// Replacement for `.tabBarMinimizeBehavior(.onScrollDown)`: the tab bar
    /// simply stays visible on iOS 18.
    @ViewBuilder
    func compatTabBarMinimizeOnScrollDown() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// iOS 18 replacement for `tabViewBottomAccessory`: the mini player is
    /// placed in a bottom safe-area inset of the tab content, directly above
    /// the tab bar. On iOS 26 this is a no-op (the real bottom accessory is
    /// used instead).
    @ViewBuilder
    func compatBottomMiniPlayerInset<Content: View>(
        isSuppressed: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            safeAreaInset(edge: .bottom) {
                if !isSuppressed {
                    content()
                }
            }
        }
    }
}

/// Replacement for `ToolbarContent.sharedBackgroundVisibility(.visible)`:
/// on iOS 18 the toolbar background is left at its default.
struct CompatSharedBackgroundVisibility<Content: ToolbarContent>:
    ToolbarContent
{
    let content: Content

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            content.sharedBackgroundVisibility(.visible)
        } else {
            content
        }
    }
}

extension ToolbarContent {
    func compatSharedBackgroundVisibility() -> some ToolbarContent {
        CompatSharedBackgroundVisibility(content: self)
    }
}

extension Color {
    /// Replacement for `Color.mix(with:by:in: .perceptual)`: on iOS 18 the two
    /// colors are interpolated in sRGB, which is visually close for the opaque
    /// colors this app mixes. Non-RGB colors fall back to the receiver.
    func compatMix(with other: Color, by amount: Double) -> Color {
        if #available(iOS 26, *) {
            return mix(with: other, by: amount, in: .perceptual)
        }
        let first = UIColor(self)
        let second = UIColor(other)
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
            second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else {
            return self
        }
        let t = CGFloat(amount)
        return Color(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            opacity: a1 + (a2 - a1) * t
        )
    }
}

extension View {
    /// Replacement for `.sliderThumbVisibility(.hidden)` (iOS 26 only):
    /// on iOS 18 the modifier does not exist, so the slider keeps its
    /// default thumb; on iOS 26 the thumb is hidden as before.
    @ViewBuilder
    func compatSliderThumbHidden() -> some View {
        if #available(iOS 26, *) {
            sliderThumbVisibility(.hidden)
        } else {
            self
        }
    }
}
