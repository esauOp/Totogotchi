## 1. Capture tokens

- [x] 1.1 Add `CaptureTokens.parse(_:now:)` in the core returning the cleaned title, priority and due date, and verify unit tests cover `!high`, `!med` and `!low` anywhere in the text and the last one winning when several appear
- [x] 1.2 Resolve `@today`, `@tomorrow` and `@mon` through `@sun` to 23:59 local, with a weekday token meaning the next occurrence including today, and verify unit tests cover the three cases the spec names: a weekday later this week, the same weekday as today, and a weekday that falls next week
- [x] 1.3 Leave unrecognised `!` and `@` text untouched in the title, and verify a unit test on "Email @maria about !urgent issue" keeps it whole with default priority and due date
- [ ] 1.4 Wire the parser into capture so Enter creates the task with the parsed values, and verify by capturing "Renew passport !high" and checking the stored task
- [ ] 1.5 Show the parsed priority and due date beside the capture field as the user types, and verify typing "Draft budget !high @fri" previews High and this Friday before Enter

## 2. Pet animation

- [x] 2.1 Add an animation layer that moves a mood's still image on a mood change, a completion and while capture is open, settling afterwards, and verify each of the five moods moves differently
- [ ] 2.2 Play a one-shot reaction on completion and a celebration when the mood becomes celebrating, returning to the mood idle within 1.5 seconds, and verify with a signpost that the override clears
- [ ] 2.3 Lean the pet towards the capture field while it is open and return to the mood idle when it closes, and verify by opening capture and pressing Esc
- [ ] 2.4 Show the owner the motion before building further on it, and record whether procedural movement is good enough or frame art is needed; note the answer in design.md
- [ ] 2.5 Fall back to static images with no reaction or celebration when Reduce Motion is on, and verify with the setting on and off
- [ ] 2.6 Pause animation on `NSWindow.occlusionState` changes and resume within 500 ms of becoming visible, and verify by covering the widget with another window for 10 seconds
- [x] 2.7 Verify average CPU stays under 1% with the widget visible and the pet at rest (the frame-rate cap was dropped: frame rate is not what drives the cost, see design.md)

## 3. Usage log

- [x] 3.1 Add a `UsageEvent` model and store in the core recording the eleven event kinds the spec lists, and verify a unit test writes and reads back each kind
- [x] 3.2 Carry identifiers and enum values only, never titles or notes, and verify a unit test asserts a recorded creation event has no title anywhere in it
- [x] 3.3 Purge events older than 90 days at launch alongside the dead-task purge, and verify a unit test with backdated events keeps the last 90 days
- [ ] 3.4 Record events from the app at their real moments: capture opened and cancelled, task created with source, completed, deleted, deferred, mood changed, notification shown and clicked, launch and quit, and verify the log after a scripted session contains each
- [x] 3.5 Verify the app still holds no network sockets and no network entitlement with the log in place

## 4. Weekly statistics and summary

- [ ] 4.1 Add a `WeeklyStats` record per ISO week accumulating deleted and deferred counts while due and completed are recomputed from tasks, kept for at least 52 weeks, and verify unit tests cover accumulation, recomputation and retention
- [ ] 4.2 Add a due-date editor to the task row's context menu so a task can be moved to a later week, and verify moving one changes its due date
- [ ] 4.3 Count a task as deferred for its original week when its due date moves out of that week into a later one, and verify a unit test sees the original week's deferred count rise and the new week's due count rise
- [ ] 4.4 Build the summary card showing tasks due, completed, completion rate, streak and the deleted-or-deferred count, and verify the figures against a seeded week
- [ ] 4.5 Show a neutral message instead of a percentage when nothing was due, and verify with an empty week
- [ ] 4.6 Trigger the card at Sunday 20:00 local or earlier when the mood becomes celebrating, at most once per ISO week, and verify both paths and that the second does not fire after the first
- [ ] 4.7 Add This Week's Summary to the status item menu so the card can be reopened, and verify it shows current figures
- [ ] 4.8 Add Dismiss, and Start Next Week after Sunday 20:00, and verify dismissing returns to the task list

## 5. Export

- [ ] 5.1 Write archive format version 2 carrying tasks, weekly statistics and usage events, and verify a round-trip reproduces all three
- [ ] 5.2 Keep reading version 1 as tasks with no history, and verify importing a version 1 file succeeds and leaves statistics and events empty

## 6. Acceptance

- [ ] 6.1 Walk every scenario in the four specs of this change as a manual QA pass against a scratch store, not the owner's tasks, and verify each passes; note any deviation in design.md
- [ ] 6.2 Verify idle CPU stays under 1% and physical footprint under 80 MB with the widget expanded, animations running and 1,000 tasks stored
- [ ] 6.3 Run `swift test` in `TotogotchiCore` and verify the whole suite passes, including the tests added by this change
