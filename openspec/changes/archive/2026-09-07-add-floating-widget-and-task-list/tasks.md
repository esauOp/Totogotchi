## 1. Week view in the core

- [x] 1.1 Add `WeekView` with overdue, this-week and completed groups, and `TaskStore.weekView(now:)` that builds it, and verify unit tests cover a task due next week being excluded, an overdue task from a previous week appearing, and a task due exactly now counting as this week
- [x] 1.2 Sort each group by due date ascending then priority high, medium, low, and verify a unit test with three tasks due the same day returns them in priority order
- [x] 1.3 Put completed tasks whose completion falls in the current ISO week into the completed group, and verify a unit test excludes one completed last week
- [x] 1.4 Add a monotonic `revision` and a closure observer registry to `TaskStore`, fired on every mutation, and verify a unit test sees the revision advance and the observer run for create, complete, rename, delete and undo
- [x] 1.5 Measure `weekView()` with 1,000 stored tasks, 60 of them due this week, over 50 runs, and verify p95 is under 100 ms; record the number in design.md

## 2. Widget window

- [x] 2.1 Add `WidgetPanelController` with a non-activating floating `NSPanel`, `.canJoinAllSpaces`, movable by background, and verify by launching that the widget stays visible over another app and after a Space switch
- [x] 2.2 Constrain the panel with `contentMinSize` 280 by 360 and `contentMaxSize` 480 by 800, defaulting to 320 by 420 on first launch, and verify dragging an edge past either bound stops at the bound
- [x] 2.3 Persist the expanded frame and collapsed state in `AppSettings`, restoring them at launch, and verify the widget reopens where it was left after a quit and relaunch
- [x] 2.4 Fall back to a centred frame on the main display when the stored frame is off every connected screen, and verify by writing an off-screen frame into preferences and relaunching
- [x] 2.5 Add collapse to a pet-only panel of at most 120 by 120 points that expands on click without losing the expanded size, and verify collapsing, relaunching and expanding returns the original frame
- [x] 2.6 Show an overdue count badge on the collapsed pet, hidden at zero, and verify with one overdue task present and then completed
- [x] 2.7 Measure launch to the widget's first frame with 1,000 stored tasks and verify it is under 1 second on Apple Silicon; record the number in design.md

## 3. Task list

- [x] 3.1 Build the list with Overdue, This Week and Completed sections, Completed collapsed by default showing its count, and verify against seeded tasks in all three states
- [x] 3.2 Mark overdue rows with both an icon and a colour and give them a VoiceOver label containing "overdue", and verify with VoiceOver on an overdue row
- [x] 3.3 Complete and uncomplete from the row checkbox and from Space with the row selected, moving the row within 300 ms, and verify with a signpost that the round trip is under 300 ms
- [x] 3.4 Add inline title editing on double-click or Return, saving on Return and cancelling on Esc, refusing an empty title with a hint, and verify all three outcomes
- [x] 3.5 Delete from the row action or the Delete key with a 5-second Undo bar that restores the task in place, and verify undo restores it and that letting the bar expire keeps it deleted
- [x] 3.6 Make arrow keys move the selection and every action reachable without a pointer, and verify Down Down Space completes the third row
- [x] 3.7 Recompute the list from the `TaskStore` observer and from a one-minute timer that is suspended while the widget is hidden or collapsed, and verify a task captured by hot key appears without touching the widget
- [x] 3.8 Measure list render with 1,000 stored tasks over 50 renders and verify p95 is under 100 ms; record the number in design.md

## 4. Menu bar and appearance

- [x] 4.1 Add Show Widget and Hide Widget to the status menu, restoring the previous frame and collapse state on show, and verify hiding and showing round-trips
- [x] 4.2 Show an overdue indicator on the status item while the widget is hidden, cleared when nothing is overdue, and verify both states
- [x] 4.3 Verify the widget renders correctly in light and dark appearance without relaunch, and that text meets a 4.5 to 1 contrast ratio
- [x] 4.4 Honour Reduce Motion by dropping the collapse and expand animation, and verify with the setting on and off

## 5. Acceptance

- [x] 5.1 Walk every scenario in the three specs of this change as a manual QA pass and verify each passes; note any deviation in design.md
- [x] 5.2 Verify idle CPU stays under 1% and physical footprint under 80 MB with the widget expanded and 1,000 tasks stored (the metric was changed from resident set size to physical footprint; see design.md and PRD §5.4)
- [x] 5.3 Run `swift test` in `TotogotchiCore` and verify the whole suite passes, including the tests added by this change
