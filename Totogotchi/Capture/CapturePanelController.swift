import AppKit
import SwiftUI
import os

/// A borderless panel that floats above other apps and takes keyboard focus
/// without activating Totogotchi, so Esc can hand focus straight back.
private final class CapturePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc reaches the panel as `cancelOperation`, which SwiftUI does not expose.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class CapturePanelController {
    private let panel: CapturePanel
    private let model: CaptureModel
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "capture")
    private var previousApp: NSRunningApplication?

    init(model: CaptureModel) {
        self.model = model

        panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 90),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = NSHostingView(rootView: CaptureFieldView(model: model))
        panel.setContentSize(panel.contentView?.fittingSize ?? panel.frame.size)

        panel.onCancel = { [weak self] in self?.hide(restoringFocus: true) }
        model.onDismiss = { [weak self] in self?.hide(restoringFocus: true) }
    }

    /// Brings the field up, or refocuses it when it is already open.
    ///
    /// `startedAt` comes from the hot key handler so the log records the full
    /// press-to-focus latency the spec budgets at 150 ms.
    func present(startedAt: CFAbsoluteTime) {
        if panel.isVisible {
            NotificationCenter.default.post(name: .captureFieldShouldFocus, object: nil)
            panel.makeKeyAndOrderFront(nil)
            log.info("Capture already open; kept text and refocused")
            return
        }

        previousApp = NSWorkspace.shared.frontmostApplication
        centerOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .captureFieldShouldFocus, object: nil)

        let elapsed = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        log.info("Capture focused \(elapsed, format: .fixed(precision: 1)) ms after the hot key")
    }

    func hide(restoringFocus: Bool) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        guard restoringFocus, let previousApp, previousApp != .current else { return }
        previousApp.activate()
        self.previousApp = nil
    }

    /// Centres the panel on whichever screen holds the pointer, so it appears
    /// where the user is already looking.
    private func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY + visible.height / 6
            )
        )
    }
}
