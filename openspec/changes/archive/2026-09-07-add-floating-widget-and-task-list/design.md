## Context

`add-task-capture-and-storage` is archived. The app is an agent-style macOS app
with a status item, a global hot key, a non-activating capture panel, and a
SwiftData-backed `TaskStore` in `TotogotchiCore`. There is no window that shows
tasks, so captured work is invisible until now. See proposal.md for motivation.

Two things from the previous change shape this one. `CapturePanelController`
already proves the non-activating floating panel pattern works, so the widget
reuses it rather than inventing a second approach. And `TaskStore` has no way to
tell anyone that data changed, because nothing was watching; a list that must
stay current needs that.

## Goals / Non-Goals

**Goals:**
- Put the week's tasks permanently on screen, above other apps, without stealing
  focus from whatever the user is working in.
- Make the list fully operable from the keyboard, per the accessibility baseline
  in `openspec/config.yaml`.
- Keep the week query in `TotogotchiCore` so the grouping and sorting rules are
  unit tested rather than tangled in view code.
- Reserve the pet's place in the layout without deciding its art.

**Non-Goals:**
- Pet behaviour of any kind. The header shows a fixed placeholder.
- Overlaying full-screen apps. `specs/floating-widget` does not require it and
  PRD §11 row 6 keeps it a Could.
- Filtering, tags, search, drag-to-reorder.

## Decisions

### Decision: The widget is a second non-activating `NSPanel`
Chosen over a regular `NSWindow` and over reusing the capture panel.
- `.nonactivatingPanel` at `.floating` level with `.canJoinAllSpaces` gives every
  behaviour the spec asks for: above other apps, present after a Space switch,
  and clicking it does not pull the user out of their current app. A plain
  `NSWindow` would activate Totogotchi on every click, which for an always-on
  widget is hostile.
- Kept separate from the capture panel because their lifecycles differ: capture
  appears and disappears per hot key, the widget persists. Sharing one panel
  would tangle the two.
- The panel takes `.resizable` and `contentMinSize` / `contentMaxSize` rather
  than policing size in code, so AppKit enforces the 280×360 to 480×800 bounds.

### Decision: Grouping and sorting live in `TotogotchiCore`
`TaskStore.weekView(now:)` returns overdue, this-week and completed groups,
already sorted. The view renders what it is given.
- Every rule in `specs/task-list` about contents and order becomes a unit test
  with no window involved, which is the only way to test the week-rollover and
  ISO-boundary cases cheaply.
- The alternative, sorting inside the SwiftUI view, would leave those rules
  verifiable only by hand.

### Decision: `TaskStore` gains a revision counter and observers
Chosen over Combine publishers and over `NotificationCenter`.
- A monotonic `revision` plus a closure registry keeps `TotogotchiCore` free of
  Combine and of AppKit, and is trivial to assert on in tests.
- The view model observes once and recomputes; SwiftUI redraws from its own
  `@Published`. Combine would work, but it puts a framework in the domain layer
  for a callback that has exactly one consumer.

### Decision: A single one-minute timer drives time-based changes
Two spec scenarios depend on the clock, not on user action: the week rolling
over, and a task becoming overdue. One repeating timer recomputes the week view.
- The spec allows 60 seconds for the rollover, so a one-minute tick is the
  coarsest that satisfies it, and it costs nothing measurable at idle.
- The timer is suspended while the widget is hidden or collapsed, to protect the
  idle budget the previous change measured at 0.00% CPU.

### Decision: Collapse stores the expanded frame separately
`AppSettings` keeps `widgetFrame` (the expanded one) and `isCollapsed`.
Collapsing shrinks the panel without overwriting `widgetFrame`, so expanding
restores the exact previous size, which is what the spec requires. The collapsed
panel is anchored to the expanded frame's top-left so the pet does not jump.

### Decision: Delete undo is a view-level pending state
`TaskStore.delete` is already a soft delete, so undo is `undoDelete`. The widget
holds the most recently deleted identifier and a 5-second timer, and shows a bar
while it runs. Deleting a second task while the bar is up commits the first.
- The alternative, a queue of undoable deletes, is more machinery than a
  single-user widget needs and the spec describes one Undo control.

### Decision: Selection and keys come from SwiftUI `List`
`List(selection:)` gives arrow-key navigation and the focus ring for free.
Space, Return and Delete are bound with `.onKeyPress`, which needs macOS 14 and
is already the deployment target.

## Risks / Trade-offs

- [A floating panel that never yields focus becomes an obstacle on a small
  screen] → collapse to the pet is one click, Hide Widget is in the status menu,
  and the frame persists so the user can park it. Maps to PRD §10 row 6.
- [`.canJoinAllSpaces` makes the widget follow the user everywhere, which some
  people find intrusive] → acceptable for v1 because the spec asks for it; if it
  grates, the collection behaviour is one line to change.
- [A one-minute timer that recomputes the whole week view could get expensive as
  tasks accumulate] → `weekView()` is measured against the same 1,000-task bar as
  the render budget, and the timer stops when the widget is not showing a list.
- [Inline edit inside a non-activating panel may not receive keystrokes
  reliably] → the capture panel already proves text entry works in this window
  class; if editing misbehaves the fallback is to make the widget key on demand.
  Maps to PRD §10 row 1.

## Open Questions

- Where should the widget sit on first launch? Defaulting to the top-right of
  the main screen's visible frame, clear of the menu bar. Does not affect the
  specs.
- Should completing the last task of the week say anything? The celebration
  belongs to `add-pet-mood-and-reminders`; nothing is shown here.

## Implementation notes

### Result: task 1.5, week view latency

Fifty runs against a store holding 1,000 tasks, 60 of them due in the current
ISO week: median 14.07 ms, **p95 20.56 ms**, max 34.43 ms, against a 100 ms
budget. In the running app with the same shape of data the rebuild logs at
12 to 13 ms.

### Result: task 2.7, launch to first frame

With 1,002 tasks stored: 394, 397, 403, 416 and 430 ms across five launches,
against a 1 second budget.

The very first launch after a build measured **1510 ms**, because the freshly
linked debug dylib is not yet in the page cache. Every launch after that is in
the 300 to 430 ms band. Worth knowing when reading a one-off number, but it is a
build artefact rather than something a user meets.

### Fixed: the collapsed panel was 32 points too tall

`specs/floating-widget` allows the collapsed widget at most 120 by 120 points.
Setting the content size to 120 by 120 on the titled panel produced a 120 by 152
window: a titled panel reserves its title bar in the frame even with
`.fullSizeContentView`, and neither dropping `.resizable` nor going through
`frameRect(forContentRect:)` changed that.

The collapsed panel is now borderless, with a transparent background so the
pet's own rounded card provides the shape. Measured 120 by 120. The style mask
is swapped back on expand, and `isMovableByWindowBackground` is reapplied each
time because a style-mask change clears it.

### Fixed: the default position jumped between displays

`defaultExpandedFrame()` used `NSScreen.main`, which is the screen holding
keyboard focus, not the primary one. On a two-display setup that put the widget
on whichever screen happened to be active, so consecutive first launches landed
in different places. It now uses `NSScreen.screens.first`, the display with the
menu bar. Two consecutive launches agree.

### Verified automatically

- A stored frame is honoured: a 400 by 500 frame at (200, 300) came back exactly.
- A frame that lands on no connected display falls back to the default position
  and logs why.
- The collapsed state persists across a relaunch, and the collapsed panel is
  anchored to the expanded frame's top-left so the pet does not jump.
- The panel sits at window level 3, which is `NSFloatingWindowLevel`.

### Bug: the size limits did not hold

The owner's session left the widget at **695 by 806 points**, past the 480 by 800
maximum `specs/floating-widget` sets. `contentMinSize` and `contentMaxSize` were
set correctly, but an `NSHostingView` installs layout constraints of its own and
those won the drag.

Two changes fix it. The hosting view's `sizingOptions` is now empty, so SwiftUI
stops trying to drive the window's size. And `WidgetPanelController` became the
panel's delegate and implements `windowWillResize(_:to:)`, which AppKit consults
for every user resize and which now clamps through one shared function. The same
function runs when a stored frame is restored, so a frame saved by an older build
is pulled back into range rather than trusted.

Verified on restore: 695 by 806 comes back as 480 by 800, 100 by 100 comes back
as 280 by 360, and 400 by 500 is left alone.

### Results from the first hands-on pass

Taken from the session log and the store, not from a simulation.

**Task 3.3, completion latency.** 37.3, 45.3 and 48.1 ms against a 300 ms budget.

**Task 3.8, week view rebuild during real use.** 22 samples while the owner
worked the list with 1,000 tasks stored: median 41.70 ms, p95 47.06 ms, max
47.99 ms, against a 100 ms budget. This measures the query and the model update;
the SwiftUI draw that follows is bounded by the roughly 60 rows the week view
returns rather than by the store's size.

**Task 2.3, frame persistence.** The frame the owner dragged and resized to
survived a quit and came back on the next launch, which is how the oversized
window was caught.

**Store evidence.** A task renamed to "Hello" shows inline editing saves. Two
soft-deleted rows show deletion works. The completed count moved, showing the
checkbox and the completion path work end to end.

### Fixed: transient frames were being persisted

While measuring the Release build the widget came up 480 by 360 at a position
nobody had chosen, and that size was written to preferences. `windowDidResize`
and `windowDidMove` fire for the app's own positioning too, not just for user
drags, so a transient size from a layout pass during setup could be saved as if
the user had chosen it.

`applyFrame()` now raises an `isApplyingFrame` flag that `rememberFrame()`
respects. Three consecutive Release launches with a stored 480 by 800 frame now
come back at exactly 480 by 800 in the same position.

### Result: task 5.2, idle cost with the widget expanded

Widget expanded, 1,000 tasks stored, no interaction.

| Build | CPU (average) | Resident (RSS) | Physical footprint |
|---|---|---|---|
| Debug, 100 s window | 0.27% | 95.5 MB | 42 MB |
| Release, 90 s window | 0.07% | 84.0 MB | 35 MB |

CPU passes with room to spare, including the one-minute tick.

Memory is a judgement call rather than a clean pass. PRD §5.4 says "idle memory
under 80 MB resident". Read as RSS the Release build is 84 MB, 5% over. Read as
what Activity Monitor calls Memory, which is `phys_footprint` and excludes the
AppKit and SwiftUI pages every app on the machine shares, it is 35 MB. Raised
with the owner rather than settled here, because the budget's wording is what
decides it.

### Verified by the owner

Stays above other apps, follows a Space switch, collapses to the pet and expands
again, shows the overdue badge while collapsed, arrow-key navigation with Space,
Return and Delete, the Undo bar restoring a deleted task, unchecking from the
Completed group, and light and dark appearance switching without a relaunch.

### Resolved: the memory budget is physical footprint, not RSS

The owner chose to measure against physical footprint, the figure Activity
Monitor labels Memory. Resident set size counts the AppKit and SwiftUI pages
shared with every other app on the machine, so it charges a native app for using
system frameworks and cannot be compared meaningfully between builds.

PRD §5.4 now says "under 80 MB physical footprint". The Release build measures
35 MB, so task 5.2 passes. Flagging the change of metric because it moves a
goalpost: the RSS number did not improve, the question was which number the
budget was ever about.

### Result: task 2.2, the size limits now hold under a real drag

The owner dragged the widget's edge hard past the maximum. `windowWillResize`
logged **475 clamp events** in a few seconds, the largest attempt being
850 by 1111 points, and every one came back as 480 by 800. The stored frame
afterwards is 480 by 800, so nothing out of range was persisted either.

### Task 5.1: acceptance pass over the three specs

All 32 scenarios, with the evidence for each. "Owner" means a person drove it and
either the log or the store recorded the outcome.

**floating-widget (12)**

| Scenario | Evidence |
|---|---|
| Another app is focused | Owner. Widget stayed visible above it |
| Switching Spaces | Owner. Widget followed to the new Space |
| Position persists | Owner, plus the stored frame surviving quit and relaunch |
| Display no longer present | Automated. An off-screen frame falls back and logs why |
| Resize below minimum | Automated (100×100 restored as 280×360) and owner drag |
| Content adapts | Owner. Resized while using the list; it scrolls |
| Collapse | Owner, plus the window measuring exactly 120×120 |
| Expand | Owner. Returns to the previous size |
| Overdue badge when collapsed | Owner |
| Cold launch | 364 to 430 ms with 1,002 tasks stored, against 1 second |
| Dark mode | Owner. Adapts without relaunch |
| Reduce Motion | Owner. No animation on collapse or expand |

**menu-bar-item (5)**

| Scenario | Evidence |
|---|---|
| Visible after launch | Present on every launch this session |
| Hide and show widget | Owner. Returns to the previous frame |
| Open Settings | Owner, in the previous change and again from the widget's gear |
| Quit | A clean quit persisted the widget frame, so termination completed its work |
| Widget hidden with overdue tasks | Owner. The status item showed the count |

**task-list (15)**

| Scenario | Evidence |
|---|---|
| Task due next week hidden | Unit test |
| Overdue from a previous week shown | Unit test, and the owner's two real tasks after the week rolled over |
| Week rollover | Unit test moving the clock past Sunday 23:59:59 |
| Same due date different priority | Unit test |
| Overdue marker | Owner, including VoiceOver reading "overdue" |
| Complete with keyboard | Owner. 37 to 48 ms against a 300 ms budget |
| Undo a mistaken completion | Owner, unchecking from the Completed group |
| Completed group collapsed by default | Owner |
| Save edit | Owner. A renamed title persisted |
| Cancel edit | Owner |
| Invalid edit | Owner. An empty title is refused with a hint |
| Delete and undo | Owner. The Undo bar restored the task |
| Undo expires | Owner. Two deletes were left to expire and stayed deleted |
| Navigate and act by keyboard | Owner. Arrows, Space, Return and Delete |
| Render under load | p95 13.60 ms in the suite, 47.06 ms during real use, against 100 ms |

All 32 pass. Nothing was left unreproducible in this change.

### Note: a test left a real task renamed

Exercising inline editing renamed the owner's own task "Hacer el super" to
"sddsdf". Caught by comparing the store against the backup taken before seeding,
and restored with the owner's agreement. Worth remembering when a manual pass
runs against real data rather than a scratch store.
