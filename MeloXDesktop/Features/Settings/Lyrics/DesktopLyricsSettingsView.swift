import SwiftUI

struct DesktopLyricsSettingsView: View {
    @State private var page: Page = .appearance

    var body: some View {
        VStack(spacing: 0) {
            Picker("ui.desktop.lyrics.settings_category", selection: $page) {
                ForEach(Page.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Group {
                switch page {
                case .appearance:
                    DesktopLyricsAppearanceSettingsView()
                case .content:
                    DesktopLyricsContentSettingsView()
                case .interaction:
                    DesktopLyricsInteractionSettingsView()
                case .animation:
                    DesktopLyricsAnimationSettingsView()
                case .extensions:
                    DesktopLyricsExtensionsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private enum Page: String, CaseIterable, Identifiable {
        case appearance
        case content
        case interaction
        case animation
        case extensions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: L10n.string("ui.desktop.lyrics.page.typography")
            case .content: L10n.string("ui.desktop.lyrics.page.content")
            case .interaction: L10n.string("ui.desktop.lyrics.page.interaction")
            case .animation: L10n.string("ui.desktop.lyrics.page.animation")
            case .extensions: L10n.string("ui.desktop.lyrics.page.extensions")
            }
        }
    }
}
