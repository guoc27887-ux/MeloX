import SwiftUI

enum DesktopPlaybackKeyboardShortcuts {
    /// macOS 15 fails to register `KeyEquivalent.space` as a modifier-less
    /// key equivalent. The string-backed shortcut works on all supported
    /// macOS versions and is safe to register in both the menu command and
    /// the player controls (SwiftUI resolves duplicate registrations to one
    /// action).
    static let togglePlayback = KeyboardShortcut(" ", modifiers: [])
}
