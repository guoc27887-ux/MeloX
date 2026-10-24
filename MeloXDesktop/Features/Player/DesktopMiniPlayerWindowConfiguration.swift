import AppKit
import SwiftUI

/// Keeps the borderless mini-player backed by a real, shadowed macOS window.
struct DesktopMiniPlayerWindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DesktopMiniPlayerWindowConfigurationView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DesktopMiniPlayerWindowConfigurationView)?.configureWindow()
    }
}

@MainActor
enum DesktopMiniPlayerWindowCoordinator {
    static func bringToFrontAfterOpening() async {
        try? await Task.sleep(for: .milliseconds(80))
        guard let miniWindow = NSApp.windows.first(where: { window in
            window.title == L10n.string("ui.desktop.mini_player")
                || (
                    abs(window.frame.width - 320) < 2
                        && window.frame.height <= 920
                )
        }) else { return }

        NSApp.activate(ignoringOtherApps: true)
        miniWindow.orderFrontRegardless()
        miniWindow.makeKey()
    }
}

private final class DesktopMiniPlayerWindowConfigurationView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    func configureWindow() {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // The mini player exposes explicit WindowDragGesture regions. Keeping
        // background dragging enabled here makes AppKit treat an NSSlider drag
        // as a window drag before SwiftUI can update its value.
        window.isMovableByWindowBackground = false
        window.invalidateShadow()
    }
}
