## Why

With capture and the visible list in place, the product still lacks its differentiator and its nudge. The PRD's value proposition is a pet whose mood reflects task health (§1), and its "Remind" journey stage needs a notification when a task is due (§3.2). This change completes the MVP defined as PRD milestone M3 (§9.3) and implements Stories 4.1 and 6.1.

## What Changes

- Add the pet mood engine: a deterministic rule set mapping weekly completion rate, overdue count and streak to one of five states (PRD §4.1.4), with boundary-tested rules.
- Render the pet in the widget header with one static image per state, a hover tooltip explaining negative states, and a short reaction when a task is completed (static image swap in this change; animation comes later).
- Add due-time notifications through the system notification center, with a permission-denied fallback (PRD §4.1.5).
- Add the streak counter and pet state to persistence.

Non-goals for this change:
- Animated pet states and celebration animation (change `add-delight-features`).
- Pet naming and skins (PRD Could).
- Repeat or snooze notifications; one notification per task per due time (PRD §4.1.5).

## Capabilities

### New Capabilities
- `pet-mood`: the mood rules, their inputs, evaluation timing, and how the state and its reason are shown to the user.
- `reminders`: when and how the user is notified about due tasks, and behavior when notifications are not permitted.

### Modified Capabilities
<!-- none: task-storage, task-list and floating-widget behavior is unchanged; the pet reads the same task data -->

## Impact

- Depends on `add-floating-widget-and-task-list` being archived (widget header slot, task queries).
- Adds PetState persistence (current mood, streak days, last evaluation time) and a notifications-enabled setting.
- Requires the user notifications entitlement and the first permission prompt in the app.
- Needs five static pet images; PRD §11 row 9 (art source) must be decided before this change starts.
- Exercises PRD §10 row 6 (pet perceived as annoying); the tooltip copy must follow the "playful, never punishing" principle (§6.1).
