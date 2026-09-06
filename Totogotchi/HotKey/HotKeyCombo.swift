import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut, stored as the Carbon virtual key code and
/// modifier mask that `RegisterEventHotKey` expects.
struct HotKeyCombo: Equatable, Codable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// Option-Command-T, the shortcut the app ships with.
    static let `default` = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(optionKey | cmdKey)
    )

    /// True when at least one modifier is held. A bare key would swallow normal
    /// typing everywhere, so the recorder refuses it.
    var hasModifier: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey) != 0
    }
}

extension HotKeyCombo: CustomStringConvertible {
    /// The shortcut as a user would read it, for example "⌥⌘T".
    var description: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + (HotKeyCombo.keyName(for: keyCode) ?? "?")
    }

    /// The printable name of a virtual key code, using the user's current layout
    /// so a French keyboard shows the key the user actually presses.
    static func keyName(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        default: break
        }

        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
