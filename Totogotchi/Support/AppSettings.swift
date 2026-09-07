import AppKit
import Foundation
import TotogotchiCore

/// User preferences, stored in the app's sandboxed defaults.
final class AppSettings {
    private enum Key {
        static let hotKey = "hotKey"
        static let fallbackNoticeShownFor = "fallbackNoticeShownFor"
        static let widgetFrame = "widgetFrame"
        static let widgetCollapsed = "widgetCollapsed"
        static let celebrationDismissedWeek = "celebrationDismissedWeek"
        static let notificationsEnabled = "notificationsEnabled"
        static let notifiedDueDates = "notifiedDueDates"
    }

    /// The expanded widget's frame. Collapsing does not overwrite it, so
    /// expanding again restores the exact size the user chose.
    var widgetFrame: NSRect? {
        get {
            guard let text = defaults.string(forKey: Key.widgetFrame) else { return nil }
            let rect = NSRectFromString(text)
            return rect.isEmpty ? nil : rect
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.widgetFrame)
                return
            }
            defaults.set(NSStringFromRect(newValue), forKey: Key.widgetFrame)
        }
    }

    var isWidgetCollapsed: Bool {
        get { defaults.bool(forKey: Key.widgetCollapsed) }
        set { defaults.set(newValue, forKey: Key.widgetCollapsed) }
    }

    /// Whether task reminders are posted at all. Independent of the system
    /// permission: the user can silence Totogotchi without touching macOS
    /// settings, and macOS can refuse regardless of this.
    var notificationsEnabled: Bool {
        get { defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    /// What has already been announced, as task identifier to the due date it
    /// was announced for. Moving a task's due date changes the value, so the new
    /// time gets its own notification.
    var notifiedDueDates: [String: Date] {
        get { defaults.dictionary(forKey: Key.notifiedDueDates) as? [String: Date] ?? [:] }
        set { defaults.set(newValue, forKey: Key.notifiedDueDates) }
    }

    /// The week whose congratulation banner the user has already dismissed, so
    /// finishing early does not mean seeing it again on Sunday.
    var celebrationDismissedWeek: ISOWeek? {
        get {
            guard let text = defaults.string(forKey: Key.celebrationDismissedWeek) else { return nil }
            let parts = text.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return ISOWeek(year: parts[0], week: parts[1])
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.celebrationDismissedWeek)
                return
            }
            defaults.set("\(newValue.year)-\(newValue.week)", forKey: Key.celebrationDismissedWeek)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The shortcut that opens quick capture. Falls back to the shipped default
    /// when nothing is stored or the stored value cannot be read.
    var hotKey: HotKeyCombo {
        get {
            guard let data = defaults.data(forKey: Key.hotKey),
                  let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data)
            else { return .default }
            return combo
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.hotKey)
        }
    }

    /// Remembers which unavailable shortcut the user has already been told about,
    /// so the launch notice appears once rather than on every start.
    func shouldShowFallbackNotice(for combo: HotKeyCombo) -> Bool {
        defaults.string(forKey: Key.fallbackNoticeShownFor) != combo.description
    }

    func recordFallbackNoticeShown(for combo: HotKeyCombo) {
        defaults.set(combo.description, forKey: Key.fallbackNoticeShownFor)
    }
}
