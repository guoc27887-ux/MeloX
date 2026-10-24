import SwiftUI

enum DesktopNowPlayingPage: String, CaseIterable, Hashable, Sendable {
    case artwork
    case lyrics
    case queue

    init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .lyrics
    }
}

struct DesktopNowPlayingPageSwitcher: View {
    @Binding var page: DesktopNowPlayingPage
    @Namespace private var selectionNamespace

    var body: some View {
        ZStack {
            surfacedContent
                .frame(width: 72, height: 36)

            HStack(spacing: -20) {
                switchButton(.lyrics, systemImage: "quote.bubble")
                switchButton(.queue, systemImage: "list.bullet")
            }
        }
        .frame(width: 92, height: 56)
    }

    @ViewBuilder
    private var surfacedContent: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.clear.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.32), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
        }
    }

    private func switchButton(
        _ destination: DesktopNowPlayingPage,
        systemImage: String
    ) -> some View {
        Button {
            page = page == destination ? .artwork : destination
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 56, height: 56)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            page == destination ? .black.opacity(0.78) : .white
        )
        .accessibilityLabel(
            destination == .lyrics
                ? L10n.string("ui.desktop.commands.show_lyrics")
                : L10n.string("ui.desktop.commands.show_queue")
        )
        .accessibilityValue(
            page == destination
                ? L10n.string("ui.common.selected")
                : L10n.string("ui.common.not_selected")
        )
        .background {
            if page == destination {
                Circle()
                    .fill(.white.opacity(0.88))
                    .frame(width: 32, height: 32)
                    .matchedGeometryEffect(
                        id: "now-playing-selected-page",
                        in: selectionNamespace
                    )
            }
        }
        // Recovered from Music 26's page-selector animator.
        .animation(.smooth(duration: 0.30), value: page)
    }
}
