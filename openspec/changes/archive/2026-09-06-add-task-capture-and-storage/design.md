## Context

Greenfield. No code, no project, no CI. The owner is the sole developer at about 10 hours per week (PRD §9.2). Constraints from `openspec/config.yaml` and PRD §5: local-only data, sandboxed, no network, performance budgets, single user. See proposal.md for motivation.

Two PRD §11 assumptions shape this design and are treated as decided here unless the owner objects: row 8 (native Swift stack) and row 7 (agent-style app without a Dock icon).

## Goals / Non-Goals

**Goals:**
- Stand up the project skeleton every later change reuses: targets, layering, test harness.
- Deliver the task model and persistence with the durability guarantees in `specs/task-storage`.
- Deliver global hotkey capture per `specs/quick-capture` in a minimal, borderless panel.
- Prove the two riskiest platform pieces early: a non-activating floating panel and sandbox-safe global hotkeys (PRD §10 rows 1 and 2).

**Non-Goals:**
- Visual design of the widget or the pet. The capture panel in this change is plain.
- Menu-bar item beyond what is needed to quit the app and open Settings.
- Data migration tooling; the schema is version 1.

## Decisions

### Decision: Native Swift, SwiftUI views, AppKit shell
Chosen over Electron and Tauri.
- Always-on-top non-activating panels, global hotkeys and Notification Center are first-class in AppKit. Electron can do always-on-top but idle memory is roughly 100 MB or more, which breaks the 80 MB budget. Tauri is lighter but its macOS window-level control is thinner and would still need native code for the hotkey.
- SwiftUI for views keeps UI code small; the panel, status item and hotkey are AppKit because SwiftUI has no API for them.
- Minimum macOS 14 so SwiftData and `@Observable` are available. Trade-off: excludes Macs stuck on macOS 13.

### Decision: SwiftData for persistence, synchronous saves
Chosen over Core Data directly and over a hand-rolled SQLite/JSON store.
- SwiftData gives a typed model, a model container inside the sandbox's Application Support directory, and SQLite with write-ahead logging underneath, which is what the forced-termination scenario needs.
- Saves are performed synchronously on mutation and the mutation call does not return until the save succeeds, so the "killed right after create" scenario holds.
- Core Data would work equally and is the fallback if SwiftData shows bugs on macOS 14; the domain layer talks to a `TaskRepository` protocol so the swap is contained.
- Soft delete is a `deletedAt` column plus a purge job at launch for rows older than 30 days.

### Decision: Global hotkey via Carbon `RegisterEventHotKey`
Chosen over `NSEvent.addGlobalMonitorForEvents` and over `CGEventTap`.
- `RegisterEventHotKey` works inside the App Sandbox without Accessibility permission and reports registration failure synchronously, which is what the conflict-detection requirement needs.
- The global `NSEvent` monitor only observes events, cannot consume them and misses some when the app is inactive. `CGEventTap` requires Accessibility permission, a poor first-run experience.
- The Carbon API is old but still supported on macOS 14 and widely used by shipping apps. Wrap it in a single `HotKeyCenter` type so it can be replaced later.

### Decision: Capture panel is a non-activating `NSPanel`
- `NSPanel` with `.nonactivatingPanel` style, floating window level, and `canBecomeKey` true lets the field take keyboard focus without activating the app, so Esc can hand focus straight back to the previous app. Track the previously frontmost app with `NSWorkspace.shared.frontmostApplication` at hotkey time.
- Alternative was activating the app and hiding it again on Esc; that causes visible window-server flicker and loses the previous app's text selection.

### Decision: Module layout
Single Xcode project, one app target, one local Swift package `TotogotchiCore` holding the domain and persistence with its own test target.
- Domain types: `Task`, `Priority`, `WeekCalendar` (ISO week math, "end of this week" helper), `TaskRepository` protocol, `TaskStore` (validation plus repository calls).
- Persistence: SwiftData models and the repository implementation live in the package so tests can run without the app target.
- App target: `HotKeyCenter`, `CapturePanelController`, SwiftUI `CaptureFieldView`, `SettingsView`, status item with Quit and Settings only.
- Pure domain logic has no AppKit or SwiftUI imports. Verified by the package compiling for tests without linking the app.

### Decision: Agent-style app
`LSUIElement` true, so no Dock icon and no main menu; the status item is the only chrome. Reversible by flipping the plist key if the owner prefers a Dock icon (PRD §11 row 7).

## Risks / Trade-offs

- [Sandbox blocks or throttles global hotkey registration] → spike `RegisterEventHotKey` in task 1.3 before any UI work; if it fails, fall back to a documented "grant Accessibility" flow with an event tap. Maps to PRD §10 row 2.
- [Non-activating panel cannot take keyboard focus on some macOS 14 point releases] → spike in task 4.1; fallback is briefly activating the app. Maps to PRD §10 row 1.
- [SwiftData synchronous save slower than 50 ms with 10,000 rows] → measure in task 3.4; fallback is a background context with an in-memory write-ahead queue and the same durability test. Maps to PRD §10 row 4.
- [Carbon API deprecation in a future macOS] → isolated behind one type; acceptable for a personal app.
- [Owner's Swift familiarity is unknown] → tasks are small and each has a concrete verification, so progress is visible even at 10 hours per week. Maps to PRD §10 row 9.

## Open Questions

- Should the capture panel appear at a fixed screen position, at the mouse location, or centered on the active display? Does not change the specs; default to centered on the display with the mouse, remembered per display once the widget exists.
- App identifier and team ID for signing; needed before notarization, not for local development.

## Implementation notes

Recorded while working through tasks.md. These are outcomes, not plans.

### Environment: Xcode is absent

The machine has only the Command Line Tools (Swift 6.2.4, macOS 26.6.2). Three
consequences, all of which block tasks rather than change decisions:

- No `.xcodeproj` tooling, so task 1.1 cannot run. Tasks 1.3, 1.4, and all of
  sections 4 and 5 depend on the app target and are blocked with it.
- No XCTest. See the test-framework note below.
- No SwiftData or Observation macro plugins. `@Model` fails with
  "plugin for module 'SwiftDataMacros' not found", so section 3 is blocked.
  The frameworks themselves are in the SDK; only the compile-time macro plugins
  are missing.

Unblocking step: install Xcode from the App Store, then
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

No temporary persistence layer was written in the meantime. The
`TaskRepository` protocol and `InMemoryTaskRepository` already provide the seam
the SwiftData implementation will slot into, so a stopgap file store would be
work thrown away.

### Decision: swift-testing instead of XCTest

Task 1.2 asked for an XCTest target. XCTest does not ship with the Command Line
Tools, and the `.xctest` bundle SwiftPM builds needs Xcode's `xctest` harness to
run. swift-testing does ship with the CLT, so the suite is an **executable
target** that calls swift-testing's own entry point:

    swift run TotogotchiCoreTests

Two workarounds live in `Package.swift`, both gated on Xcode being absent so
they disappear once it is installed:

- The Testing framework and its macro plugin are off the default search paths,
  so `-F` and `-plugin-path` point at them.
- The CLT ships `_Testing_Foundation.framework` without its swiftmodule, so the
  Foundation cross-import overlay cannot resolve. `-disable-cross-import-overlays`
  turns it off; nothing in the suite needs what the overlay adds.

When Xcode is installed this should move back to a regular `.testTarget`, and
the tests port to XCTest or stay on swift-testing, which Xcode also runs.

### Decision: the model type is `TaskItem`, not `Task`

`Task` collides with Swift concurrency's `Task`. Shadowing it inside the module
would make every later use of structured concurrency awkward. `TaskItem` costs
nothing and avoids the problem.

### Note: end of week is 23:59:59

`specs/task-storage` says the default due date is "Sunday 23:59 local". The
implementation uses Sunday 23:59:59, derived by taking the ISO week interval's
end and subtracting one second. This keeps weeks contiguous with no gap and
survives daylight-saving transitions, which is verified in both directions.

### Bug found by the tests

The first full run crashed with "Attempted to read an unowned reference but
object was already destroyed". The test clock captured itself `unowned` in the
closure handed to `TaskStore`, and tests that discarded the clock let it
deallocate while the store still held the closure. Changed to a strong capture;
there is no cycle because the clock does not hold the closure.

### Status after this session

Done and verified: tasks 1.2 and 2.1 through 2.4. `swift run TotogotchiCoreTests`
reports 28 tests in 3 suites passing, covering task defaults, title validation
at the 200/201 boundary, completion-timestamp clamping, overdue rules, soft
delete with undo and the 30-day purge boundary, and `WeekCalendar` across the
2026/2027 year boundary, both daylight-saving transitions, and four locales
including Islamic and Persian calendars.

### Session two: Xcode installed

The environment blocker above is gone. Xcode 26.6 is active, so the app target,
SwiftData and XCTest are all available. The `Package.swift` workarounds were
removed and the suite is a normal `.testTarget` again, run with `swift test`.
The tests stay on swift-testing, which Xcode runs natively.

**Project generation.** No `xcodegen` or `tuist` is installed, so
`Totogotchi.xcodeproj/project.pbxproj` was written by hand using the
`PBXFileSystemSynchronizedRootGroup` format (objectVersion 77). The app target
points at the `Totogotchi/` folder and Xcode picks up files as they are added,
so the project file does not change when sources do. `Config/Totogotchi.entitlements`
sits outside that folder so it cannot be swept into the bundle as a resource.

**Signing.** `CODE_SIGN_IDENTITY = "-"` with manual style, so the app builds and
runs locally without a team. Xcode reports "Disabling hardened runtime with
ad-hoc codesigning": Hardened Runtime needs a Developer ID, so it comes back on
when signing for distribution. The setting stays on in the project.

### Result: task 1.3, hot key registration under the sandbox

`RegisterEventHotKey` **works** inside the App Sandbox with no Accessibility
permission and no extra entitlement. The log line at launch reads
`Registered global hot key ⌥⌘T`. No fallback to `CGEventTap` is needed, which
closes the PRD §10 row 2 risk for registration.

One thing to watch: on macOS 26 the process makes a `kTCCServiceListenEvent`
request at startup with `preflight_unknown`. Apple now has a privacy gate around
listening for key events, so the system may prompt the user the first time a
shortcut actually fires. Registration itself is not gated.

### Result: task 3.4, save latency

With 10,000 tasks in the store, 100 timed single-task saves gave a median of
0.75 ms, **p95 of 3.66 ms**, and a maximum of 6.46 ms. The budget is 50 ms, so
there is more than an order of magnitude of headroom and no explicit index is
needed. `#Index` and `#Unique` both require macOS 15 and the deployment target
is 14, so uniqueness uses `@Attribute(.unique)` and there are no declared
indexes.

Seeding those 10,000 rows took 12.4 s, about 1.24 ms each, because every write
is its own transaction. That is the right trade for interactive use and the
durability guarantee, but a future bulk import of a large archive should batch
its saves.

### Note: archive timestamps

The JSON export encodes dates as ISO-8601 with fractional seconds. That is
readable and accurate to the millisecond, but the decimal text rounds, so a
round trip lands within a millisecond of the original rather than on the
identical `Double`. Nothing in the app records anything finer.

### Note: the capture field stays open after Enter

`specs/quick-capture` says the field clears within 100 ms of Enter; it does not
say the panel closes. It stays open so several tasks can be captured in a row
during a meeting, which is the workflow the PRD describes. Esc closes it.

### Verified automatically

- App launches with no Dock icon: `background only` is true for the process.
- The store opens inside the sandbox container at
  `~/Library/Containers/com.esauortega.Totogotchi/Data/Library/Application Support/Totogotchi/`,
  with `-wal` and `-shm` files present, confirming write-ahead logging.
- Launch maintenance runs and reports how many dead records it purged.
- The global shortcut registers.

### Still to verify by hand

Synthesising a key press or a menu click needs Accessibility permission for the
shell, which was refused. These need a person at the keyboard: the hot key
actually firing (1.3), quitting from the status menu (1.4), everything in
section 4, everything in section 5, and the `kill -9` durability check (3.6).

### Results from the first hands-on pass

The owner drove the app from the keyboard. Everything below came from that
session's log, not from a simulation.

**Task 4.2, press-to-focus latency.** 41.9 ms on the first press of a cold
launch, then 4.6, 2.5 and 2.1 ms. The budget is 150 ms, so even the cold path
has more than three times the headroom.

**Task 4.3, create latency.** 12.6 ms and 5.9 ms against a 100 ms budget.

**Task 1.3, the hot key fires.** ⌥⌘T opened the capture field from another app.
macOS 26 did not prompt for the `kTCCServiceListenEvent` permission its startup
request hinted at, so nothing extra is needed for a locally built, sandboxed app.

**Task 4.5, Esc.** Closes the panel and returns focus to the previous app.

**Task 3.6, forced termination.** Two tasks were created through the panel, the
process was killed with `kill -9`, and both survived the relaunch with their
priority and due date intact. The due date read `2026-09-06 23:59:59`, the
Sunday that ends that ISO week, which also confirms `WeekCalendar` end-to-end in
the real app.

### Bug: Settings did nothing

The status item's Settings command called
`NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`, which
returned false without a trace. SwiftUI's `Settings` scene installs its command
in the app menu, and an `LSUIElement` app has no menu bar, so nothing in the
responder chain handles the selector.

Fixed by owning the window: `SettingsWindowController` builds an `NSWindow`
around `SettingsView` and shows it directly. This does not depend on a private
selector whose name has already changed once between macOS releases
(`showPreferencesWindow:` to `showSettingsWindow:`), and it works for an
accessory app. The `Settings` scene stays in the `App` body only because `App`
requires a scene; it renders `EmptyView`.

### Result: task 6.2, idle cost

Thirty seconds of idle sampling with the panel closed: the process's total CPU
time did not advance at all, so **0.00% average** against a 1% budget. Resident
memory was **68.6 MB** against an 80 MB budget, with a physical footprint of
21 MB. There are no timers or animations in this change, so idle cost should
stay flat until the pet arrives.

### Result: task 5.3, launch-time fallback

Staged by writing a shortcut with no modifiers into the app's stored
preferences, then relaunching. The log shows the whole path:

    Could not register Space: noModifier
    Registered global hot key ⌥⌘T

The default was then persisted, so the fallback cannot loop, and the one-time
notice appeared as a modal.

### Finding: Carbon accepts almost any shortcut, including the system's

While looking for a shortcut that would fail to register, ⌘Space was tried.
`RegisterEventHotKey` **accepted it**, and the app took over Spotlight's
shortcut for as long as it ran. Two consequences:

1. Task 5.2's premise, "a shortcut the system rejects", is close to
   untriggerable. Registration failure is rare; the same handling is exercised
   by 5.3 through the `noModifier` guard, and both go through the one
   `register()` path that keeps the previous shortcut on failure.
2. There is nothing stopping a user from shadowing a system shortcut and
   quietly breaking it. Worth a warning in the recorder later. Not in scope for
   this change, but it belongs in the widget/settings work that follows.

### Task 6.1: acceptance pass over both specs

Every scenario in `specs/quick-capture/spec.md` and `specs/task-storage/spec.md`,
with the evidence for each. "Manual" means the owner drove it from the keyboard
and the app's log recorded the outcome.

**quick-capture (12 scenarios)**

| Scenario | Evidence |
|---|---|
| Hotkey from another app | Manual. Panel opened from other apps |
| Hotkey while capture already open | Manual. `Capture already open; kept text and refocused`, twice |
| Successful capture | Manual. Two tasks landed in the store |
| Empty capture rejected | Manual. `Capture refused: A task needs a title.` |
| Over-long capture rejected | Manual. `A title can be at most 200 characters; this one is 2575.` |
| Cancel returns focus | Manual. Esc closed the panel and restored the previous app |
| First launch default | ⌥⌘T registered on a store with no saved preference |
| Custom hotkey persists | Manual. ⌥⇧Space recorded, survived a quit and relaunch, then changed back |
| Shortcut unavailable | **Not reproducible.** See the Carbon finding above |
| Registration fails at launch | Staged. Fallback to ⌥⌘T, default persisted, notice shown |
| Capture with all windows hidden | Every capture in this change: no widget exists yet |

**task-storage (14 scenarios)**

| Scenario | Evidence |
|---|---|
| New task has defaults | Unit tests, and the app stored medium priority due `2026-09-06 23:59:59` |
| Completion timestamp is never in the future | Unit test on the clamp |
| Whitespace-only title rejected | Unit tests over four inputs, plus the manual pass |
| Title trimmed | Unit test |
| Over-long title rejected | Unit tests at 200 and 201, plus the manual pass at 2575 |
| Deleted task is hidden but recoverable | Unit test comparing the restored task field by field |
| Deleted tasks are purged | Unit test at the 30-day boundary, and a SwiftData-backed test |
| Restore after normal relaunch | SwiftData test reopening the store, plus the app |
| Restore after forced termination | `kill -9` on the running app; both tasks survived |
| Storage lives in the sandbox | Store resolved inside the app container, with `-wal` and `-shm` |
| Network disabled | The app holds no IP sockets, and the sandbox grants no network entitlement, so the kernel denies connections outright |
| Save under load | p95 3.66 ms with 10,000 tasks stored |
| Export round-trip | 50 mixed tasks compared field by field |
| Export writes only where chosen | The export directory contained exactly one file |

One of 26 scenarios could not be reproduced, for the reason recorded above. All
others pass.

### Task 5.2: the original verification was not achievable

The task said to verify by "recording a shortcut the system rejects". No such
shortcut was found: `RegisterEventHotKey` accepted everything tried, including
⌘Space. The handling itself is one code path, `HotKeyController.register`
returning false, and it was exercised at launch in 5.3, where the previous
shortcut was kept and a message shown. The task's verification line was rewritten
to say that, rather than leaving a checkbox that nothing on this machine can
tick. Flagging it here because it is a changed goalpost, not a passed test.
