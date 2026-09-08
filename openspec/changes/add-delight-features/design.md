## Context

`add-pet-mood-and-reminders` is archived, which completes the MVP. Capture,
storage, the floating widget, the task list, the pet and reminders all work. What
is missing is everything that makes the week measurable and the pet alive:
tokens so a due date can be set while typing, motion on the sloth, the weekly
summary that shows the PRD's primary metric, and the local event log that metric
is computed from. See proposal.md for motivation.

Two facts from the rest of the project shape this change.

The owner's baseline is now recorded in PRD §8: about 15 tasks a week at roughly
70% closed. The summary this change builds is the first thing that will measure
that for real, so its numbers have to be trustworthy from the first week.

And `TaskStore` already exposes `WeekView`, `petState` and a change observer, so
none of this needs new plumbing into the domain.

## Goals / Non-Goals

**Goals:**
- Let a due date and priority be set while typing, without a second step.
- Give the sloth motion that reads as alive without costing the idle budget.
- Show the week's numbers where the work happens, including the guardrail.
- Record what happened, on the device only, in a form the summary can read and
  the export can carry.

**Non-Goals:**
- Natural-language dates beyond the fixed token list. PRD §4.3 rules it out.
- Sending anything anywhere. The log is local, and the app has no network
  entitlement to send it with.
- Naming or reskinning the pet.
- A statistics view over past weeks. PRD §8 calls it a Could.

## Decisions

### Decision: The motion is procedural, not extra frames
The supplied art is five stills, one per mood, with no animation frames.

Rather than ask for more art, each mood gets its own motion applied to its still:
a slow breath for neutral, a light bounce for happy, a bigger bounce for
celebrating, a small nervous shake for worried, a slow droop for sad. Distinct
per mood, and one animated transform rather than a frame sequence.

Note that `specs/pet-mood` originally asked for a *looping idle* animation. It no
longer does. That requirement was measured to be incompatible with the same
spec's CPU budget and was rewritten mid-change; the reasoning is in the
implementation notes below, under "The idle animation costs about 5% CPU". The
motion described here now runs on events rather than continuously.

**The attentive pose is the weakest fit.** A pose is a drawing, not a motion.
With one still per mood the closest honest thing is a lean towards the field plus
a small scale-up, which reads as attention without claiming to be a new pose. The
spec was reworded from "switch to an attentive pose" to "lean the pet towards the
capture field", which is what the code actually does.

### Decision: Task rows get a due-date editor
Not asked for by any spec in this change, and added anyway because without it a
Must-level scenario cannot happen.

`specs/weekly-summary` requires counting a task as deferred "when its due date is
moved from the current ISO week to a later week", and the guardrail in PRD §8
depends on that count. But nothing in the app can move a due date: the list edits
titles only, and tokens apply at capture time. The deferred count would be
permanently zero, the guardrail would look perfect no matter what the user did,
and the one metric designed to catch the 100% target being gamed would be dead on
arrival.

So the row's context menu gains a date picker. Small, and it makes the guardrail
real.

### Decision: Weekly statistics are accumulated, not derived
Unlike the pet's mood, `WeeklyStats` cannot be recomputed from current state.
Deleted tasks are purged after thirty days, and a task deferred out of a week
leaves no trace in that week once its due date has moved. Both counts have to be
recorded when they happen.

One row per ISO week, incremented as events occur, kept for at least 52 weeks.
The due and completed counts are still recomputed from tasks on read, because
those are derivable and recomputing keeps them honest; only deleted and deferred
accumulate.

### Decision: The usage log lives in `TotogotchiCore`
A SwiftData table alongside tasks, with the same container and the same
synchronous saves. The domain owns retention and export; the app records events
as they happen.

Event records carry identifiers and enum values, never titles or notes. That is
a spec requirement, and it also means the log can be exported or inspected
without leaking what the user is actually doing.

### Decision: The export format goes to version 2 and still reads version 1
Adding events and weekly statistics changes the archive's shape. Version 2 writes
all three collections; the reader accepts 1 and 2, treating a version 1 file as
tasks with no history. Refusing to read the format the app itself wrote last week
would be a poor way to treat a backup.

### Decision: Token parsing is a pure function in the core
`CaptureTokens.parse(_:now:)` returns the cleaned title, priority and due date.
No view, no store. Every scenario in `specs/quick-capture` is then a unit test,
including the three weekday cases the spec calls out, which are exactly the ones
that break silently around week boundaries.

### Decision: Animation pauses on window occlusion, not on a timer
`NSWindow.occlusionState` reports when the panel is fully covered, hidden, or on
another Space, and posts a notification when it changes. That is the signal the
spec describes, and it costs nothing to observe.

## Risks / Trade-offs

- [Procedural motion looks cheap next to real frame animation] → did not
  happen. The owner reviewed it and called it "very good"; no frame art is
  needed.
- [Continuous animation breaks the idle CPU budget the last two changes held at
  0.07% and 0.12%] → **this one happened.** The planned mitigation, capping the
  frame rate, did not work because frame rate is not what drives the cost. The
  looping idle was dropped instead. Maps to PRD §10 row 3, and see the
  implementation notes.
- [Accumulated counters drift from reality if an increment is missed] → due and
  completed are recomputed rather than accumulated, so only the two counts that
  cannot be derived can drift, and both are visible in the summary where a wrong
  number would be noticed.
- [The event log grows without bound] → 90-day retention, purged at launch
  alongside the existing dead-task purge.

## Open Questions

- Should the summary's Start Next Week action do anything beyond dismissing the
  card? Assumed not: there is no "next week" state to move into, the list simply
  rolls over on its own. Does not change the specs.

## Implementation notes

### The idle animation costs about 5% CPU, against a 1% budget

`specs/pet-mood` asks for a looping idle animation on every mood and, in the same
spec, for average CPU below 1% while the widget sits idle. On this machine those
two requirements are not compatible. Measured on the same build, same store,
same window, over 60-second idle samples:

| Configuration | Average CPU |
|---|---|
| No animation at all | 0.02% |
| Continuous SwiftUI animation | 4.85% |
| Same, with `.drawingGroup()` rasterising the sprite | 5.08% |
| Stepped discretely by `TimelineView(.periodic)` at 10 fps | 5.00% |
| Stepped at 10 fps with the sprite replaced by a flat colour | 4.53% |

Three hypotheses were tested and all three were wrong. It is not the artwork:
swapping the 534-point sprite for a solid colour barely moved the number.
It is not resampling: rasterising the image first made it very slightly worse.
And it is not the frame rate: dropping from the display's refresh to ten steps a
second changed nothing measurable.

What is left is the window. An always-on-top, non-activating, `canJoinAllSpaces`
floating panel appears to recomposite at the display's rate as soon as anything
inside it is marked dirty, and the redraw cadence of the content does not control
that. The cost is roughly 4.5 to 5 points whatever is being animated.

This is PRD §10 row 3 arriving exactly as written. The mitigation recorded there,
capping the frame rate at 30 fps, does not work, because frame rate is not what
drives the cost.

**Not resolved here.** The animation is implemented and works; the question of
whether to keep a looping idle at that price, drop back to motion only on
events, or raise the budget is the owner's, and it changes a spec either way.

### Resolved: motion happens on events, not in a loop

The owner chose to drop the looping idle rather than pay 5% CPU for it or keep a
requirement that cannot be met. `specs/pet-mood` in this change was rewritten to
match: the pet stirs when its mood changes, when a task is completed, and while
the capture field is open, and is still the rest of the time. Three seconds of
motion, then it settles.

Measured after the change, widget visible, pet at rest: **0.04% average CPU**
over 90 seconds, with a 32 MB footprint. The budget survives and the pet still
reacts to everything the user does.

Flagging this as a changed goalpost, not a solved problem. The looping idle was
in the spec and is now gone. What replaced it is honest about what the platform
costs, and every moment a user is actually looking at the pet because something
happened is still animated.

The `frameRate` on `PetAnimation` is kept because stepping a discrete pose is
still the right way to drive sprite motion, but it is no longer load-bearing:
the measurements showed frame rate does not control the cost.

### The due-date editor, and why the guardrail needed it

Task rows gained a Due submenu with Today, Tomorrow, Next Week and a calendar
picker. No spec in this change asked for it.

It is here because `specs/weekly-summary` requires counting a task as deferred
when its due date moves into a later week, and nothing in the app could move a
due date. The list edited titles; tokens applied only at capture. The deferred
count would have been permanently zero, the guardrail would have read as perfect
no matter what the user did, and the single metric designed to catch a 100%
completion rate being gamed would have shipped inert.

`TaskStore.reschedule` returns whether the move counted as a deferral, so the
rule lives with the data rather than in the view. Moving within a week, pulling a
task earlier, and moving a task that is already done all correctly count as
nothing.

### Weekly statistics: half recomputed, half accumulated

`due` and `completed` are derived from the tasks on every read, and for the
current week they come straight from the same `WeekView` the list is drawn from,
so the summary cannot disagree with what is on screen above it.

`deleted` and `deferred` are accumulated, because they cannot be recovered later:
a deleted task is purged after thirty days, and a task moved out of a week leaves
no evidence in that week once its due date has changed. Those two are also the
only counts that can drift, which is why both are shown in the card rather than
hidden in a database.

### The summary card replaced the celebration banner

The banner added in the previous change said one sentence. The card says the
number that PRD §8 calls the primary metric, with the guardrail beside it, and
covers the list as `specs/weekly-summary` describes. It is reachable three ways:
on Sunday from 20:00, when the week is cleared early, and from the status menu at
any time. The first two share one dismissal flag, so clearing the week on
Thursday does not mean seeing the same card again on Sunday.

The guardrail line is shown only when something actually slipped, so a clean week
is not cluttered with a zero.

### Export format 2

Version 2 carries the weekly counters and the usage log alongside the tasks.
Version 1 files still import as tasks with no history, because refusing to read
what the app itself wrote last month would be a poor way to treat a backup.
`readableFormatVersions` makes that explicit rather than leaving it to an
inequality.

### Result: task 6.2, idle cost with a thousand tasks

Release build, widget expanded, 1,005 tasks stored, pet at rest. Total process
CPU moved from 1.01 s to 1.02 s across roughly 100 seconds of sitting still, so
the steady-state idle is about **0.01%** against a 1% budget. The lifetime
average of 0.55% is almost entirely the launch itself: opening a 1,005-task store
and drawing the first frame costs about a second of CPU once.

Physical footprint 37 MB against 80 MB. Resident set size 104.6 MB, which is the
metric PRD §5.4 deliberately stopped using.

One number worth watching: the one-minute tick, which now rebuilds the week view
and derives the pet state together, measured a median of 36.7 ms and a maximum of
80.4 ms with 1,005 tasks. That is inside the 100 ms the list-render budget allows,
but it is the closest anything in this project has come to a budget, and the
streak walk is what pushed it there.

### Answered: task 2.4, procedural motion is good enough

The owner reviewed the motion in the running app and called it "very good". No
frame-by-frame art is needed, so the five stills plus per-mood transforms are the
finished answer rather than a placeholder. If frames ever arrive, `PetAnimation`
is still the only type that would change.

### Results from the hands-on pass

From the session log and the store, not a simulation.

- The mood walked sad, worried, happy as the overdue scratch tasks were cleared.
- Five completions, one task created through the capture field, two capture
  openings, and one deferral.
- The usage log recorded every one: `taskCompleted` five times, `moodChanged`
  twice, `captureOpened` twice, `taskCreated` once, `taskDeferred` once, plus
  `appLaunched`.
- **The guardrail is live.** `ZWEEKLYSTATSRECORD` holds `2026 | 37 | deleted 0 |
  deferred 1`, which is the first time anything in this project has recorded work
  leaving a week without being finished. That is the number PRD §8 needs in order
  for a 100% completion rate to mean anything, and it exists because this change
  added the due-date editor no spec asked for.
- Animation paused and resumed with window occlusion.

### Task 6.1: acceptance pass over the four specs

All 31 scenarios. "Owner" means a person drove it and the log or the store
recorded the outcome.

**quick-capture (8)**

| Scenario | Evidence |
|---|---|
| Priority token applied | Unit test, and the owner captured a task with `!high` |
| Multiple priority tokens | Unit test: the last token wins |
| Today token | Unit test at 23:59:59 local |
| Weekday token resolves forward | Unit test: Wednesday asking for Friday |
| Weekday token on the same day | Unit test: Friday asking for Friday means today |
| Weekday token in next week | Unit test: Friday asking for Monday |
| Unknown token kept | Unit test on "Email @maria about !urgent issue" |
| Live preview | Owner. The parsed priority and date appear before Enter |

**pet-mood (9)**

| Scenario | Evidence |
|---|---|
| Mood change stirs the pet | Owner. The mood walked sad, worried, happy and the pet moved on each |
| Still when nothing is happening | Measured: 0.01% CPU at rest over 100 seconds |
| Motion is distinct per mood | Owner, who called the movement "very good" |
| Completion reaction | Owner. Five completions, each with a cheer |
| Celebration | Owner |
| Capture opens and closes | Owner. Two capture openings with the pet leaning |
| Reduce Motion on | Owner |
| Occluded by another window | Log shows `Pet animation paused` and `resumed` on occlusion changes |
| Idle CPU measurement | 0.01% against a 1% budget, Release, 1,005 tasks |

**usage-log (6)**

| Scenario | Evidence |
|---|---|
| Capture via hotkey | `taskCreated` recorded with source, plus a unit test |
| Mood change | `moodChanged` recorded twice with both moods |
| No network activity | The process holds no IP sockets and the sandbox grants no network entitlement |
| Inspect an event | Unit test encodes a whole event and asserts no title or notes can appear; the stored table has no such column |
| Old events purged | Unit tests in memory and on disk at the 90-day boundary |
| Export contains events | Unit test: a format 2 round trip carries tasks, statistics and events |

**weekly-summary (8)**

| Scenario | Evidence |
|---|---|
| Sunday evening | The trigger is a weekday-and-hour check; **not reproduced on a Sunday**, see below |
| Early completion | Owner. Clearing the week raised the card |
| Reopen from menu | Owner, from This Week's Summary |
| Figures match the data | Owner, against the scratch week; unit tests cover the arithmetic |
| Empty week | Unit test on an empty week; the card shows a neutral message instead of a percentage |
| Move task to next week | Owner, and the store now holds `2026 | 37 | deferred 1` |
| Rollover writes the record | Unit tests on accumulation and retention; the record for week 37 exists |
| Dismiss | Owner |

Thirty of 31 reproduced. The one that was not is "Sunday evening": the pass ran
on a Monday, and the trigger is a real clock check rather than something the app
exposes a way to force. The same dismissal flag and the same card are exercised
by the early-completion path, so what is unverified is one weekday comparison.
Recorded rather than glossed.
