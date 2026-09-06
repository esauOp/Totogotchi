import AppKit
import Carbon.HIToolbox
import Combine
import os

/// Owns the app's single global shortcut: which one is active, what happens when
/// registration is refused, and what the user is told about it.
@MainActor
final class HotKeyController: ObservableObject {
    @Published private(set) var combo: HotKeyCombo
    /// Set when something went wrong that the user should see in Settings.
    @Published var statusMessage: String?

    private let center = HotKeyCenter()
    private let settings: AppSettings
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "hotkey")
    private var action: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        combo = settings.hotKey
    }

    /// Registers the stored shortcut at launch.
    ///
    /// If it cannot be registered, the app falls back to the shipped default and
    /// says so once, so a shortcut claimed by another app does not silently leave
    /// capture unreachable.
    func activate(action: @escaping () -> Void) {
        self.action = action
        let stored = settings.hotKey

        if register(stored) {
            combo = stored
            return
        }

        guard stored != .default, register(.default) else {
            statusMessage = "Quick capture has no working shortcut. Choose another one below."
            log.error("No shortcut could be registered, including the default")
            return
        }

        combo = .default
        settings.hotKey = .default
        statusMessage = "\(stored.description) was unavailable, so quick capture is back on \(HotKeyCombo.default.description)."
        if settings.shouldShowFallbackNotice(for: stored) {
            settings.recordFallbackNoticeShown(for: stored)
            presentFallbackNotice(from: stored)
        }
    }

    /// Applies a shortcut the user just recorded.
    ///
    /// A shortcut the system refuses leaves the previous one in place, so the
    /// user is never left without a way to capture.
    func record(_ candidate: HotKeyCombo) {
        guard candidate != combo else { return }
        let previous = combo

        if register(candidate) {
            combo = candidate
            settings.hotKey = candidate
            statusMessage = nil
            return
        }

        _ = register(previous)
        statusMessage = "\(candidate.description) is already used by macOS or another app. Still using \(previous.description)."
    }

    private func register(_ candidate: HotKeyCombo) -> Bool {
        guard let action else { return false }
        do {
            try center.register(candidate, handler: action)
            return true
        } catch {
            log.error("Could not register \(candidate.description, privacy: .public): \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func presentFallbackNotice(from unavailable: HotKeyCombo) {
        let alert = NSAlert()
        alert.messageText = "Quick capture moved to \(HotKeyCombo.default.description)"
        alert.informativeText = """
            \(unavailable.description) is no longer available, probably because macOS or \
            another app claimed it. You can pick a different shortcut in Totogotchi's settings.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }
}

extension HotKeyCombo {
    /// Builds a shortcut from a recorded key press, or nil when no modifier is
    /// held; a bare key would swallow ordinary typing system-wide.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
        guard hasModifier else { return nil }
    }
}
