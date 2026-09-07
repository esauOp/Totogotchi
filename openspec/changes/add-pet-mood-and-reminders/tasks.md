## 1. Pet art

- [x] 1.1 Slice the supplied sprite sheet into five transparent images on one shared canvas, aligned on a common baseline so the body does not change size between moods, and verify a contact sheet shows five clean sprites
- [x] 1.2 Add them to `Totogotchi/Assets.xcassets` as `PetHappy`, `PetNeutral`, `PetCelebrating`, `PetSad` and `PetWorried`, and verify the app builds and each image loads by name
- [x] 1.3 Record the art's provenance and licence position in the repo, and verify PRD §11 row 9 is closed

## 2. Mood engine

- [x] 2.1 Add `PetMood` and a `PetState` value carrying the mood, its reason and the numbers behind it, and verify the type compiles with no dependency on AppKit or SwiftUI
- [x] 2.2 Add `TaskStore.streakDays(now:)` walking days backwards, counting a day that had a completion or had nothing due, capped at 365 days, and verify unit tests cover an unbroken run, a gap day with nothing due, a break, and today still in progress
- [x] 2.3 Implement `MoodEngine.evaluate(weekView:streakDays:)` with the rules from `specs/pet-mood` in order, and verify unit tests at every boundary the spec names: O = 0, 1 and 3, C = 0.49 and 0.5, S = 2 and 3
- [x] 2.4 Give each mood a reason string that names the cause and the next action without blaming, and verify a test asserts the worried reason contains the overdue count
- [x] 2.5 Measure `streakDays` plus `evaluate` over 1,000 stored tasks across 50 runs and verify p95 is under 100 ms; record the number in design.md

## 3. Pet in the widget

- [x] 3.1 Replace the placeholder paw print in the widget header and the collapsed view with the mood's image, and verify each of the five moods renders by forcing the state
- [x] 3.2 Recompute the mood whenever the week view changes and at least every 15 minutes, and verify completing the last overdue task changes the pet within 500 ms using a signpost
- [x] 3.3 Show the reason as a tooltip on hover and expose the mood and reason to VoiceOver, and verify with the pointer and with VoiceOver on a worried state
- [x] 3.4 Show the celebrating sloth for at most 1.5 seconds when a task is completed, then return to the computed mood, and verify with a signpost that the override clears
- [x] 3.5 Show a congratulation banner in the widget when the mood becomes celebrating, dismissible and not shown again that week, and verify by completing the last task due this week

## 4. Reminders

- [x] 4.1 Add `ReminderScheduler` that posts a notification carrying the task title within 60 seconds of its due time while the app runs, riding the existing one-minute tick, and verify with a task due a minute ahead
- [x] 4.2 Record what has been notified as task identifier to due date so a task is never notified twice for the same time, and verify a second tick posts nothing and that moving the due date posts again at the new time
- [x] 4.3 Post one summary notification at launch for tasks that came due while the app was not running, and verify with two tasks backdated before launch
- [x] 4.4 Expand the widget and highlight the task when its notification is clicked, and verify by clicking one
- [x] 4.5 Request permission the first time a task with a due time is created, and verify the prompt appears once
- [x] 4.6 Keep everything else working when permission is denied, and show in Settings how to enable it, and verify by denying permission and letting a task come due
- [x] 4.7 Add a notifications toggle in Settings that works independently of the system permission, and verify a task coming due with the toggle off posts nothing while the pet still reacts
- [x] 4.8 Prune notification records for tasks that no longer exist at launch, and verify the record shrinks after a task is purged

## 5. Acceptance

- [x] 5.1 Walk every scenario in both specs of this change as a manual QA pass and verify each passes; note any deviation in design.md
- [x] 5.2 Verify idle CPU stays under 1% and physical footprint under 80 MB with the widget expanded and 1,000 tasks stored
- [x] 5.3 Run `swift test` in `TotogotchiCore` and verify the whole suite passes, including the tests added by this change
