## Why

After `add-task-capture-and-storage`, tasks can be captured but not seen. The PRD's core pain is that tasks are forgotten because the list is hidden (§2.1, §3.2 "Track"). This change makes the week's tasks permanently visible in a small always-on-top widget and lets the user complete, edit and delete them. It is PRD milestone M2 (§9.3) and implements Stories 2.1, 2.2 and 3.1, plus the menu-bar item from §4.2 that an agent-style app needs.

## What Changes

- Add a floating, always-on-top, draggable, resizable widget window that persists its frame and can collapse to a small pet-sized square (PRD §4.1.3, §6.2).
- Add the week view task list: overdue plus current ISO week, sorted by due date then priority, with a collapsed Completed section (PRD §4.1.2).
- Add task actions in the list: complete, uncomplete, inline edit, delete with 5-second undo, all keyboard-operable (Story 2.2).
- Add the menu-bar item with Show/Hide widget, Settings and Quit (PRD §4.2).
- Reserve the header area where the pet will render; this change shows a static placeholder image.

Non-goals for this change:
- Pet mood logic and reactions (change `add-pet-mood-and-reminders`).
- Overlay above full-screen apps (PRD Could, §11 row 6).
- Tags, projects, recurring tasks, sub-tasks (PRD §4.2 Could and §4.3).

## Capabilities

### New Capabilities
- `floating-widget`: the always-on-top window, its persistence, collapse and resize behavior, and launch performance.
- `task-list`: which tasks are shown, in what order, and the complete / edit / delete / undo interactions.
- `menu-bar-item`: the status-bar menu that controls the app when it has no Dock icon.

### Modified Capabilities
<!-- none: task-storage and quick-capture behavior is unchanged; the list reads through the existing store -->

## Impact

- Depends on `add-task-capture-and-storage` being archived (task store, `WeekCalendar`, settings persistence).
- Adds widget frame and collapsed state to persisted settings.
- Introduces the first substantial SwiftUI view hierarchy and the accessibility baseline (VoiceOver labels, keyboard operation) that later UI inherits.
- PRD §10 row 1 (window behavior across Spaces and displays) is exercised here.
