import Carbon.HIToolbox
import Foundation
import os

/// Registers one system-wide keyboard shortcut and calls back when it fires.
///
/// Uses Carbon's `RegisterEventHotKey` rather than an `NSEvent` global monitor
/// or a `CGEventTap`: it works inside the App Sandbox with no Accessibility
/// permission, it consumes the keystroke so the frontmost app never sees it, and
/// it reports failure synchronously, which is what conflict detection needs.
@MainActor
final class HotKeyCenter {
    enum Failure: Error, Equatable {
        /// The shortcut is already taken, by the system or another app.
        case registrationRefused(OSStatus)
        case handlerInstallationFailed(OSStatus)
        case noModifier
    }

    private static let signature: OSType = 0x544F_544F // 'TOTO'

    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "hotkey")
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    private(set) var registeredCombo: HotKeyCombo?

    /// No deinit cleanup: the app owns a single center for its whole lifetime,
    /// and Carbon releases the registration when the process exits.

    /// Makes `combo` the active shortcut. Any previous one is released first, and
    /// on failure nothing stays registered so the caller can restore the old one.
    func register(_ combo: HotKeyCombo, handler: @escaping () -> Void) throws {
        guard combo.hasModifier else { throw Failure.noModifier }

        unregister()
        try installEventHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            log.error("Registering \(combo.description, privacy: .public) failed with status \(status)")
            throw Failure.registrationRefused(status)
        }

        hotKeyRef = reference
        registeredCombo = combo
        self.handler = handler
        log.info("Registered global hot key \(combo.description, privacy: .public)")
    }

    /// Invoked from the Carbon callback once the event has been identified.
    fileprivate func fire() {
        handler?()
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        registeredCombo = nil
        handler = nil
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }

        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var reference: EventHandlerRef?

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr, identifier.signature == HotKeyCenter.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                // Carbon delivers hot keys on the main run loop, so the hop is
                // an assertion rather than a dispatch.
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { center.fire() }
                return noErr
            },
            1,
            &specification,
            Unmanaged.passUnretained(self).toOpaque(),
            &reference
        )

        guard status == noErr else {
            log.error("Installing the hot key event handler failed with status \(status)")
            throw Failure.handlerInstallationFailed(status)
        }
        eventHandler = reference
    }
}
