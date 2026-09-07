import AppKit
import SwiftUI

/// Owns the Settings window.
///
/// SwiftUI's `Settings` scene hangs its "Settings…" command off the app menu, and
/// an `LSUIElement` app has no menu bar for it to attach to, so
/// `showSettingsWindow:` never reaches a responder. Managing a plain `NSWindow`
/// keeps this working and does not depend on a selector whose name has changed
/// between macOS releases.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(hotKeys: HotKeyController, notifications: NotificationsController) {
        let window = window ?? makeWindow(hotKeys: hotKeys, notifications: notifications)
        self.window = window

        // An accessory app has to ask for activation explicitly, or the window
        // opens behind whatever the user was working in.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow(hotKeys: HotKeyController, notifications: NotificationsController) -> NSWindow {
        let hosting = NSHostingView(rootView: SettingsView(hotKeys: hotKeys, notifications: notifications))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Totogotchi Settings"
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        // Closing Settings should hide it, not destroy it: the app keeps running
        // and the window is reused next time.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
