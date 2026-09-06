import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A field that listens for the next key press and reports it as a shortcut.
struct HotKeyRecorder: NSViewRepresentable {
    let combo: HotKeyCombo
    let onRecord: (HotKeyCombo) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.combo = combo
        view.onRecord = onRecord
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var combo: HotKeyCombo = .default
        var onRecord: ((HotKeyCombo) -> Void)?
        private var isRecording = false {
            didSet { needsDisplay = true }
        }

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 24) }
        override var isFlipped: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            // Esc leaves recording without changing anything.
            if event.keyCode == UInt16(kVK_Escape) {
                isRecording = false
                window?.makeFirstResponder(nil)
                return
            }
            guard let recorded = HotKeyCombo(event: event) else {
                NSSound.beep()
                return
            }
            isRecording = false
            window?.makeFirstResponder(nil)
            onRecord?(recorded)
        }

        override func draw(_ dirtyRect: NSRect) {
            let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
            rounded.fill()
            (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            rounded.stroke()

            let text = isRecording ? "Press a shortcut\u{2026}" : combo.description
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                withAttributes: attributes
            )
        }

        override func accessibilityLabel() -> String? { "Quick capture shortcut" }
        override func accessibilityValue() -> Any? { combo.description }
    }
}
