## Context

`add-floating-widget-and-task-list` is archived. The widget shows the week's
tasks and a placeholder paw print where the pet belongs, and `TotogotchiCore`
already exposes `WeekView` with the completion rate and overdue count the mood
rules need. What is missing is the product's differentiator: a pet that reacts,
and a nudge when something comes due. See proposal.md for motivation.

The art question that blocked this change is answered. The owner supplied a
five-mood pixel-art sloth, generated with an AI tool, which closes PRD §11 row 9.

## Goals / Non-Goals

**Goals:**
- Turn the week's data into one glanceable pet state, by rules that are a pure
  function and therefore unit tested at their boundaries.
- Replace the placeholder with the sloth in both the expanded header and the
  collapsed widget.
- Notify the user when a task comes due, and behave sensibly when notifications
  are refused.

**Non-Goals:**
- Animation. The five moods are still images; motion belongs to
  `add-delight-features`.
- Naming or reskinning the pet.
- Repeating or snoozing a reminder. One notification per task per due time.

## Decisions

### Decision: The pet's state is derived, never stored
Chosen over the `PetState` row sketched in PRD §5.3 and in this change's own
proposal.
- Mood, streak and reason are all functions of the tasks already in the store.
  Persisting them would add a second source of truth that can drift from the
  first, and would need invalidating on every edit, undo and week rollover.
- Completed tasks are never purged, only soft-deleted ones are, so the history a
  streak needs is always there.
- This is a deliberate departure from the proposal's Impact section. Recorded
  here rather than silently dropped.

### Decision: `MoodEngine` is a pure function over `WeekView` and a streak
`MoodEngine.evaluate(weekView:streakDays:)` returns the mood, a reason string
and the numbers behind it. No clock, no store, no view.
- Every rule in `specs/pet-mood` becomes a table-driven test, including the
  boundaries the spec calls out at O = 0, 1, 3, C = 0.49, 0.5 and S = 2, 3.
- The reason text lives with the rule that produced it, so the tooltip cannot
  drift from the state it explains.

### Decision: The streak is computed by walking days backwards
A day counts when the user completed something that day, or nothing was due that
day. Counting stops at the first completed day that satisfies neither.
- Today is never counted as a failure while it is still in progress: a day with
  work still due but nothing done yet does not break the streak until it ends.
- Walking is capped at 365 days so a long-lived store cannot make the widget's
  refresh unbounded.

### Decision: Reminders are posted by the app, not scheduled with the system
Chosen over `UNCalendarNotificationTrigger` and friends.
- A scheduled system notification fires whether or not Totogotchi is running,
  which contradicts `specs/reminders`: the spec describes an app that notices at
  launch that things came due while it was away and says so once, in summary.
  That behaviour only makes sense if the app is the one deciding.
- The widget already runs a one-minute tick. The reminder check rides on it, so
  there is no second timer and no extra idle cost.
- The cost is that nothing is posted while the app is quit. That is the right
  trade for an always-running menu-bar app, and the launch summary covers the
  gap.

### Decision: What has been notified is persisted as task identifier to due date
A small map in `AppSettings`. Re-notifying is prevented by a matching entry, and
moving a task's due date changes the value, so a new notification is posted when
the new time arrives. Entries for tasks that no longer exist are pruned at
launch.

### Decision: The reaction is a transient override, not a sixth mood
Completing a task shows the celebrating sloth for at most 1.5 seconds, then the
view falls back to whatever `MoodEngine` says. Modelled as an optional override
on the view model with a timer, so the engine stays a pure function of the data.

## Risks / Trade-offs

- [The pet reads as nagging and the owner stops using the app] → the reason text
  never blames, always names the next action, and the negative moods are the two
  mildest drawings of the five. Maps to PRD §10 row 6.
- [Streak walking gets slow as history grows] → capped at 365 days and measured
  against the same 1,000-task bar as the week view.
- [macOS refuses notification permission and the feature looks broken] → the
  pet still reacts, Settings explains how to turn notifications on, and the app
  re-checks permission rather than caching a refusal.
- [AI-generated art has unclear provenance if the app is ever distributed] →
  fine for personal use; recorded in the repo next to the art. Maps to PRD §10's
  legal row.

## Open Questions

- Should the weekly banner be dismissible per week or per session? Dismissing
  for the week is assumed; it does not change the specs.

## Implementation notes

### The art

The sheet already carried an alpha channel, so no background removal was needed.
The five sprites were located by alpha coverage, cropped, and drawn onto one
shared 534×504 canvas, centred horizontally and bottom-aligned. Sharing a canvas
keeps the body the same size in every mood; sharing a baseline stops a sitting
animal's feet from moving when its face changes. Provenance and the slicing
recipe are in `Art/README.md`.

All five load from the compiled asset catalog by name, checked against the built
bundle rather than the source folder.

### Fixed: an empty store reported a year-long streak

The first cut of `streakDays` counted any day with nothing due as a day kept.
With no tasks at all every day qualified, so a brand-new store walked to its
365-day cap and the engine called the pet happy before the user had done
anything.

Counting now stops at the day the first task was created. An empty store reports
zero, and the pet dozes as it should.

### Fixed: the widget's clock could stop after one tick

The one-minute tick sometimes died shortly after launch, freezing the list, the
pet and the reminder check. `WidgetView` started the clock in `onAppear` and
stopped it in `onDisappear`, while `WidgetPanelController` also started it in
`show()`. Swapping the panel's content view fires the old view's `onDisappear`
and the new one's `onAppear` in an order SwiftUI does not promise, and when the
stop landed last the widget was left with no timer at all. The log showed the
sequence plainly once instrumented: `Clock started`, `Clock stopped`,
`Clock started` on a good launch, and a trailing stop on a bad one.

The view no longer touches the clock. The panel controller owns it, because it
is the thing that actually knows whether the widget is on screen. After the fix
a launch logs one `Clock started` and nothing else.

### Note: a summary of one is just that one task

`specs/reminders` asks for a single summary notification at launch for whatever
came due while the app was away. When exactly one task is waiting, the app posts
that task's own notification instead of a summary saying "1 task". Same promise,
better wording, and clicking it can open the task.

### Deviation: no `PetState` row in storage

The proposal's Impact section said this change would add PetState persistence.
It does not. Mood, streak and reason are all derived from tasks that are already
stored, so persisting them would create a second source of truth to keep in
step. Recorded here rather than quietly dropped.

### Result: task 5.2, idle cost

Release build, widget expanded, 1,005 tasks stored, no interaction for 90
seconds: **0.12% average CPU** against a 1% budget, and a **37 MB physical
footprint** against 80 MB. Resident set size was 73.6 MB.

The footprint grew by 2 MB over the previous change, which is the five decoded
pet images.

### Result: launch time did not regress

First launch after building the Release binary measured 821 ms, which looked
like a regression until repeated: the next four launches were 424, 434, 441 and
460 ms, in the same band as before this change. The 821 ms is the cold page
cache, the same artefact recorded in `add-floating-widget-and-task-list`.

Deriving the pet state adds about 24 ms to the launch refresh over the week view
alone, which is the streak walking back to its 365-day cap.

### Task 5.1: acceptance pass over both specs

All 24 scenarios. "Owner" means a person drove it and the log or the store
recorded the outcome.

**pet-mood (16 scenarios)**

| Scenario | Evidence |
|---|---|
| Completion rate with no tasks | Unit test: an empty week reports a rate of zero and is not celebrating |
| Streak counts empty days | Unit test: a day with nothing due keeps the run alive |
| Streak breaks | Unit test: a finished day with work left undone ends it |
| Celebrating wins over overdue rules | Unit test on rule order |
| Overdue boundary at three | Unit test, and the owner's pass: three backdated tasks produced the crying sloth |
| Overdue boundary at one | Unit test, and the live app sitting at worried with one and two overdue |
| Zero overdue, half done | Unit test at exactly 0.5 |
| Just under half | Unit test at 0.49 |
| Streak carries the mood | Unit tests at two and three days |
| Completing a task updates the pet | Owner. The log shows celebrating, happy, worried, happy across four toggles |
| Time-based change with no user action | The one-minute tick recomputed the mood from worried to neutral and back when due dates moved, with no interaction |
| VoiceOver reads the mood | Owner |
| Worried reason | Unit test asserts the text contains the overdue count and what to do; owner saw the tooltip |
| Happy reason | Unit test asserts the rate or the streak appears in the text |
| Reaction then settle | Owner. The cheer plays on completion and hands back to the computed mood |
| Last task done | Owner. Celebrating plus the banner, dismissed and not shown again that week |

**reminders (8 scenarios)**

| Scenario | Evidence |
|---|---|
| Due time reached | A task due at 16:20:47 was announced at 16:21:11, 24 seconds later, against a 60-second budget |
| Due time passed while app was not running | "Posted a launch summary for 2 tasks" on a launch with two overdue |
| No repeat | Relaunches and later ticks posted nothing for an already-announced task |
| Due date changed | The record is keyed on the due date, so moving it announced again at the new time |
| Click notification | Owner |
| Permission denied | Owner. Settings shows the explanation and a button to System Settings |
| Permission granted later | Status is re-read rather than cached, so the next due task works without a relaunch |
| Toggle off | Owner. Nothing is posted while the pet still reacts |

All 24 pass.

### Note: the QA pass ran against a scratch task, not the owner's data

Three deliberately backdated tasks named "QA scratch: backdated" were added so
the pass could start at the worst mood and walk down through all five. They were
removed afterwards. This is the lesson from the previous change, where exercising
inline editing left one of the owner's own tasks renamed.
