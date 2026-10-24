import AppKit
import SwiftUI

struct DesktopFloatingLyricsWindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DesktopFloatingLyricsWindowConfigurationView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DesktopFloatingLyricsWindowConfigurationView)?
            .configureWindow()
    }
}

enum DesktopFloatingLyricsWindowMetrics {
    static let defaultWidth: CGFloat = 420
    static let defaultHeight: CGFloat = 96
    static let minimumWidth: CGFloat = 300
    static let minimumHeight: CGFloat = 72
}

private final class DesktopFloatingLyricsWindowConfigurationView: NSView {
    private static let sizingVersion = 1
    private static let sizingVersionKey = "floatingLyrics.windowSizingVersion"

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    func configureWindow() {
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(
            width: DesktopFloatingLyricsWindowMetrics.minimumWidth,
            height: DesktopFloatingLyricsWindowMetrics.minimumHeight
        )
        window.collectionBehavior.formUnion([
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
        ])
        applyDefaultSizeIfNeeded(to: window)
        window.invalidateShadow()
    }

    private func applyDefaultSizeIfNeeded(to window: NSWindow) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.sizingVersionKey)
            < Self.sizingVersion else {
            return
        }

        window.setContentSize(
            NSSize(
                width: DesktopFloatingLyricsWindowMetrics.defaultWidth,
                height: DesktopFloatingLyricsWindowMetrics.defaultHeight
            )
        )
        defaults.set(Self.sizingVersion, forKey: Self.sizingVersionKey)
    }
}
