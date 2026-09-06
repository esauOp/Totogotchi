## Why

Totogotchi does not exist yet. The owner captures tasks in daily and weekly meetings, loses them because capture is slow and the list is not visible, and ends the week with incomplete work (PRD §2.1). The fastest path to value is the core loop's first half: capture a task in one step from any app and never lose it. This change is PRD milestone M1 (§9.3) and implements Stories 1.1 and 5.1.

## What Changes

- Create the macOS app project, an agent-style app with no main window yet.
- Add local, on-device task storage with soft delete, zero-loss restore, and JSON export (PRD §4.1.6, §5.3).
- Add quick capture: a global hotkey opens an inline capture field; Enter creates a task with default priority and due date; Esc cancels (PRD §4.1.1).
- Add hotkey configuration with conflict detection.
- Establish the layered module structure and unit-test harness that later changes build on (PRD §5.1).

Non-goals for this change (implemented later or never, PRD §4.3):
- The floating widget and task list UI (change `add-floating-widget-and-task-list`).
- Inline tokens such as `!high` or `@fri` (change `add-delight-features`).
- Any pet behavior, notifications, iCloud sync, or cloud accounts.

## Capabilities

### New Capabilities
- `task-storage`: the task data model, its validation rules, on-device persistence, durability and export guarantees.
- `quick-capture`: creating a task from anywhere via a global hotkey and an inline field, including defaults, cancellation, and hotkey configuration.

### Modified Capabilities
<!-- none: greenfield project -->

## Impact

- New Xcode project and Swift packages; no existing code affected.
- Requires App Sandbox entitlements only for the app container; no network entitlement.
- Establishes the persistence schema that changes 2 through 4 extend (PetState, WeeklyStats, EventLog are added later).
- PRD §11 items to confirm before or during this change: row 7 (agent-style app, no Dock icon) and row 8 (Swift/SwiftUI/SwiftData stack).
