import AppKit
import SwiftUI

/// Keeps the native sidebar-backed `TabView` permanently visible.
///
/// SwiftUI can remove its standard toolbar item, but it does not expose the
/// AppKit flags that prevent a macOS sidebar from being collapsed by dragging
/// its divider or by resizing the window. This probe also reports the native
/// sidebar frame so SwiftUI can align fixed content with the resizable column.
/// The sidebar content itself remains fully SwiftUI-owned.
struct DesktopSidebarVisibilityLock: NSViewRepresentable {
    @Binding private var sidebarFrame: CGRect
    let reservedBottomInset: CGFloat

    init(
        sidebarFrame: Binding<CGRect>,
        reservedBottomInset: CGFloat = 0
    ) {
        _sidebarFrame = sidebarFrame
        self.reservedBottomInset = reservedBottomInset
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sidebarFrame: $sidebarFrame,
            reservedBottomInset: reservedBottomInset
        )
    }

    func makeNSView(context: Context) -> DesktopSidebarVisibilityProbe {
        let probe = DesktopSidebarVisibilityProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return probe
    }

    func updateNSView(
        _ nsView: DesktopSidebarVisibilityProbe,
        context: Context
    ) {
        context.coordinator.sidebarFrame = $sidebarFrame
        context.coordinator.reservedBottomInset = reservedBottomInset
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopSidebarVisibilityProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private weak var installedSidebarItem: NSSplitViewItem?
        private weak var installedSidebarScrollView: NSScrollView?
        private var windowUpdateObserver: NSObjectProtocol?
        private var deferredConfigurationTask: Task<Void, Never>?
        private var frameReportingTask: Task<Void, Never>?
        private var reportedSidebarFrame: CGRect?
        private var originalBottomContentInset: CGFloat?
        var sidebarFrame: Binding<CGRect>
        var reservedBottomInset: CGFloat

        init(
            sidebarFrame: Binding<CGRect>,
            reservedBottomInset: CGFloat
        ) {
            self.sidebarFrame = sidebarFrame
            self.reservedBottomInset = reservedBottomInset
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                configureWindow()
                return
            }

            detach()
            installedWindow = window

            guard let window else { return }
            windowUpdateObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.configureWindow()
                }
            }

            configureWindow()
            deferredConfigurationTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled else { return }
                self?.configureWindow()
            }
        }

        func detach() {
            deferredConfigurationTask?.cancel()
            deferredConfigurationTask = nil
            frameReportingTask?.cancel()
            frameReportingTask = nil

            if let windowUpdateObserver {
                NotificationCenter.default.removeObserver(windowUpdateObserver)
            }
            windowUpdateObserver = nil
            restoreOriginalBottomContentInset()
            installedSidebarItem = nil
            installedSidebarScrollView = nil
            installedWindow = nil
            reportedSidebarFrame = nil
            originalBottomContentInset = nil
        }

        private func configureWindow() {
            guard let window = installedWindow else { return }
            removeSidebarToggle(from: window.toolbar)

            if let installedSidebarItem,
               installedSidebarItem.viewController.view.window === window {
                lock(installedSidebarItem)
                return
            }
            installedSidebarItem = nil

            var configuredControllers = Set<ObjectIdentifier>()
            if let rootViewController = window.contentViewController {
                lockSidebarItems(
                    below: rootViewController,
                    configuredControllers: &configuredControllers
                )
            }
            if let contentView = window.contentView {
                lockSidebarItems(
                    below: contentView,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func removeSidebarToggle(from toolbar: NSToolbar?) {
            guard let toolbar else { return }

            let indexes = toolbar.items.indices.filter { index in
                let identifier = toolbar.items[index].itemIdentifier
                if identifier == .toggleSidebar {
                    return true
                }

                let rawIdentifier = identifier.rawValue.lowercased()
                return rawIdentifier.contains("sidebar")
                    && rawIdentifier.contains("toggle")
            }

            for index in indexes.reversed() {
                toolbar.removeItem(at: index)
            }
        }

        private func lockSidebarItems(
            below viewController: NSViewController,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            if let splitViewController = viewController as? NSSplitViewController {
                lockSidebarItems(
                    in: splitViewController,
                    configuredControllers: &configuredControllers
                )
            }

            for child in viewController.children {
                lockSidebarItems(
                    below: child,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func lockSidebarItems(
            below view: NSView,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            if let splitView = view as? NSSplitView,
               let splitViewController = splitView.delegate
                as? NSSplitViewController {
                lockSidebarItems(
                    in: splitViewController,
                    configuredControllers: &configuredControllers
                )
            }

            for subview in view.subviews {
                lockSidebarItems(
                    below: subview,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func lockSidebarItems(
            in splitViewController: NSSplitViewController,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            let identifier = ObjectIdentifier(splitViewController)
            guard configuredControllers.insert(identifier).inserted else {
                return
            }

            for item in splitViewController.splitViewItems
            where item.behavior == .sidebar {
                installedSidebarItem = item
                lock(item)
            }
        }

        private func lock(_ item: NSSplitViewItem) {
            if item.isCollapsed {
                item.isCollapsed = false
            }
            if item.canCollapse {
                item.canCollapse = false
            }
            if item.canCollapseFromWindowResize {
                item.canCollapseFromWindowResize = false
            }
            if item.isSpringLoaded {
                item.isSpringLoaded = false
            }

            reserveFooterSpace(below: item.viewController.view)
            reportFrame(of: item)
        }

        private func reserveFooterSpace(below view: NSView) {
            guard let scrollView = firstScrollView(below: view) else { return }

            if installedSidebarScrollView !== scrollView {
                restoreOriginalBottomContentInset()
                installedSidebarScrollView = scrollView
                originalBottomContentInset = scrollView.contentInsets.bottom
            }

            var contentInsets = scrollView.contentInsets
            contentInsets.bottom = (originalBottomContentInset ?? 0)
                + reservedBottomInset
            guard abs(scrollView.contentInsets.bottom - contentInsets.bottom)
                > .ulpOfOne else {
                return
            }
            scrollView.contentInsets = contentInsets
        }

        private func firstScrollView(below view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }

            for subview in view.subviews {
                if let scrollView = firstScrollView(below: subview) {
                    return scrollView
                }
            }
            return nil
        }

        private func restoreOriginalBottomContentInset() {
            guard let scrollView = installedSidebarScrollView,
                  let originalBottomContentInset else {
                return
            }

            var contentInsets = scrollView.contentInsets
            contentInsets.bottom = originalBottomContentInset
            scrollView.contentInsets = contentInsets
        }

        private func reportFrame(of item: NSSplitViewItem) {
            guard let contentView = installedWindow?.contentView else { return }

            let sidebarView = item.viewController.view
            let frame = sidebarView.convert(sidebarView.bounds, to: contentView)
            guard frame.width > 0,
                  frame.height > 0,
                  reportedSidebarFrame != frame else {
                return
            }

            reportedSidebarFrame = frame
            frameReportingTask?.cancel()
            frameReportingTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled,
                      self?.reportedSidebarFrame == frame else {
                    return
                }
                self?.sidebarFrame.wrappedValue = frame
            }
        }
    }
}

final class DesktopSidebarVisibilityProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
