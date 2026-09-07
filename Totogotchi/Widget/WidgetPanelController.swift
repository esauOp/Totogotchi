import AppKit
import SwiftUI
import os

/// The always-on-top widget window.
///
/// A non-activating floating panel, like the capture panel, so clicking the
/// widget never pulls the user out of the app they are working in. Kept separate
/// from `CapturePanelController` because the two have opposite lifetimes: capture
/// comes and goes with the hot key, the widget stays.
@MainActor
final class WidgetPanelController: NSObject, NSWindowDelegate {
    private enum Size {
        static let expandedDefault = NSSize(width: 320, height: 420)
        static let minimum = NSSize(width: 280, height: 360)
        static let maximum = NSSize(width: 480, height: 800)
        static let collapsed = NSSize(width: 120, height: 120)
    }

    private let panel: NSPanel
    private let model: WidgetViewModel
    private let settings: AppSettings
    private let onOpenSettings: () -> Void
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "widget")

    private var isCollapsed: Bool
    /// True while the controller is positioning the panel itself. Delegate
    /// callbacks that arrive during that window describe a size the app chose,
    /// sometimes a transient one from a layout pass mid-setup, and persisting it
    /// once left a widget stored at its minimum height.
    private var isApplyingFrame = false
    private var launchedAt: CFAbsoluteTime?
    private var hasLoggedFirstFrame = false

    init(model: WidgetViewModel, settings: AppSettings, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        isCollapsed = settings.isWidgetCollapsed

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Size.expandedDefault),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Totogotchi"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Follows the user across Spaces, which is what an always-visible widget
        // has to do. Deliberately not `.fullScreenAuxiliary`: overlaying
        // full-screen apps is out of scope for this change.
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init()
        panel.delegate = self
        applyContent()
        applyFrame()
    }

    var isVisible: Bool { panel.isVisible }

    // MARK: - NSWindowDelegate

    /// The authority on how big the widget may get.
    ///
    /// `contentMaxSize` alone did not hold: an `NSHostingView` installs its own
    /// layout constraints and a drag could push the window past the bounds, which
    /// is how a 695 by 806 widget got past the 480 by 800 limit. This hook runs
    /// for every user resize, so the bounds cannot be escaped.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let allowed = isCollapsed ? Size.collapsed : Self.clamped(frameSize)
        if allowed != frameSize {
            log.info(
                "Clamped a resize from \(Int(frameSize.width))x\(Int(frameSize.height)) to \(Int(allowed.width))x\(Int(allowed.height))"
            )
        }
        return allowed
    }

    func windowDidResize(_ notification: Notification) {
        rememberFrame()
    }

    func windowDidMove(_ notification: Notification) {
        rememberFrame()
    }

    /// Holds a size inside the range `specs/floating-widget` allows.
    private static func clamped(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, Size.minimum.width), Size.maximum.width),
            height: min(max(size.height, Size.minimum.height), Size.maximum.height)
        )
    }

    // MARK: - Showing

    func show(measuringLaunchFrom start: CFAbsoluteTime? = nil) {
        launchedAt = start
        applyContent()
        applyFrame()
        panel.orderFrontRegardless()
        if isCollapsed { model.stopClock() } else { model.startClock() }
        logFirstFrameIfNeeded()
    }

    func hide() {
        rememberFrame()
        panel.orderOut(nil)
        model.stopClock()
    }

    func toggleVisibility() {
        isVisible ? hide() : show()
    }

    // MARK: - Collapsing

    func toggleCollapsed() {
        rememberFrame()
        isCollapsed.toggle()
        settings.isWidgetCollapsed = isCollapsed
        applyContent()
        applyFrame()
        if isCollapsed { model.stopClock() } else { model.startClock() }
    }

    // MARK: - Content

    private func applyContent() {
        let hosting: NSHostingView<AnyView>
        if isCollapsed {
            hosting = NSHostingView(
                rootView: AnyView(
                    CollapsedPetView(overdueCount: model.overdueCount) { [weak self] in
                        self?.toggleCollapsed()
                    }
                )
            )
        } else {
            hosting = NSHostingView(
                rootView: AnyView(
                    WidgetView(
                        model: model,
                        onCollapse: { [weak self] in self?.toggleCollapsed() },
                        onOpenSettings: onOpenSettings
                    )
                )
            )
        }
        // Without this the hosting view adds constraints of its own that fight
        // the window's size limits.
        hosting.sizingOptions = []
        panel.contentView = hosting

        if isCollapsed {
            // Borderless, because a titled panel reserves its 32-point title bar
            // even with `.fullSizeContentView`, which made the collapsed window
            // 120 by 152 instead of the 120 by 120 the spec allows. Equal
            // minimum and maximum then pin it so it cannot be dragged into
            // something that is no longer "pet only".
            panel.styleMask = [.nonactivatingPanel, .borderless]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentMinSize = Size.collapsed
            panel.contentMaxSize = Size.collapsed
        } else {
            panel.styleMask = [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable]
            panel.isOpaque = true
            panel.backgroundColor = .windowBackgroundColor
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentMinSize = Size.minimum
            panel.contentMaxSize = Size.maximum
        }
        // A borderless panel loses this on every style-mask change.
        panel.isMovableByWindowBackground = true
    }

    // MARK: - Frame

    /// Places the panel: collapsed panels hang off the expanded frame's top-left
    /// corner so the pet does not jump when the widget folds up.
    private func applyFrame() {
        isApplyingFrame = true
        defer { isApplyingFrame = false }
        let expanded = validated(settings.widgetFrame) ?? defaultExpandedFrame()
        // Anchor on the top-left corner so the pet stays put when the widget
        // folds up, rather than the window growing downwards from its origin.
        let topLeft = NSPoint(x: expanded.minX, y: expanded.maxY)
        // A stored frame from an older build, or one saved before the limits
        // were enforced, is pulled back into range rather than trusted.
        panel.setContentSize(isCollapsed ? Size.collapsed : Self.clamped(expanded.size))
        panel.setFrameTopLeftPoint(topLeft)
    }

    /// Saves the expanded frame only. Collapsing must not overwrite the size the
    /// user chose for the list.
    private func rememberFrame() {
        guard !isApplyingFrame, !isCollapsed, panel.isVisible else { return }
        settings.widgetFrame = panel.frame
    }

    /// Rejects a stored frame that no longer lands on a connected display.
    private func validated(_ frame: NSRect?) -> NSRect? {
        guard let frame, !frame.isEmpty else { return nil }
        let fitsSomewhere = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
        guard fitsSomewhere else {
            log.info("Stored widget frame is off every connected display; using the default position instead")
            return nil
        }
        return frame
    }

    /// Top-right of the primary display, clear of the menu bar.
    ///
    /// Deliberately not `NSScreen.main`, which is whichever screen currently has
    /// keyboard focus and so moves the default position between launches on a
    /// multi-display setup. `screens.first` is the display holding the menu bar.
    private func defaultExpandedFrame() -> NSRect {
        guard let visible = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame else {
            return NSRect(origin: .zero, size: Size.expandedDefault)
        }
        let size = Size.expandedDefault
        return NSRect(
            x: visible.maxX - size.width - 24,
            y: visible.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
    }

    private func logFirstFrameIfNeeded() {
        guard !hasLoggedFirstFrame, let launchedAt else { return }
        hasLoggedFirstFrame = true
        // Measured after the next turn of the run loop, which is the first time
        // the panel has actually drawn.
        DispatchQueue.main.async { [log] in
            let elapsed = (CFAbsoluteTimeGetCurrent() - launchedAt) * 1_000
            log.info("Widget first frame \(elapsed, format: .fixed(precision: 1)) ms after launch")
        }
    }

    /// Called before the app exits so the last position is not lost.
    func persistState() {
        rememberFrame()
    }
}
