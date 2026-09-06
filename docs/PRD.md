# Totogotchi — Product Requirements Document

| Field | Value |
|---|---|
| Product | Totogotchi |
| Owner | Esau Ortega (product, design, engineering) |
| Status | Draft |
| Last updated | 2026-09-06 |
| Version | 0.2 |

---

## 1. Executive Summary

- **Vision:** Totogotchi is a macOS task manager that lives in a small always-on-top widget where a virtual pet's mood reflects how well you are completing your week's tasks.
- **Target user and primary use case:** An individual Mac user who collects tasks during daily and weekly meetings, needs to prioritize them, and forgets items when they are not visible. Primary use case: capture a task in seconds without leaving the current app, then see and complete the week's tasks from a widget that is always on screen.
- **Key differentiator and value proposition:** Existing task apps are hidden in a window or a menu bar. Totogotchi keeps tasks and a reactive, animated pet permanently visible. Completing tasks keeps the pet happy; ignoring them makes it visibly worried. The emotional feedback loop turns task hygiene into a small game instead of a chore.
- **Success definition:** Primary KPI is **weekly task completion rate** (tasks completed ÷ tasks due in the ISO week). Target: **100%** for the owner's own use, measured every Sunday. See §8 for guardrails against gaming this metric.
- **Strategic alignment:** Supports the owner's personal-growth goal (shipping a complete native app; improving personal task discipline). Solves the stated pain points: weak task management and forgetting things. Market timing: `[TBD — needs data]`; no market research has been done (see §2).
- **Resource summary:** One person, part-time. Skills needed: Swift/SwiftUI, basic 2D animation or sprite art, macOS notification and window APIs. `[ASSUMPTION: MVP effort ≈ 6–8 part-time weeks; no budget beyond an Apple Developer account if App Store distribution is chosen.]`

---

## 2. Problem Statement & Opportunity

### 2.1 Problem definition
The owner records tasks in daily and weekly meetings, but current tooling does not keep them visible or make prioritizing easy. Result: tasks are forgotten "on the way" and the week ends with incomplete work.

Quantified impact: `[TBD — needs data]`. Evidence that would fill the gap: two weeks of manual logging of (a) tasks captured, (b) tasks completed by Sunday, (c) tasks forgotten and rediscovered late. This also produces the baseline for §8.

Supporting evidence provided by the owner:
- Pain point: "Not a good task management and forgetting some things on the way."
- Feature request: "A quick way to create tasks", "always visible", "funny or even animated way to see and manage."

### 2.2 Opportunity analysis
- **Market size and growth:** `[TBD — needs data]`. Not required for a personal-use release.
- **User segment:** Individual Mac users who want a lightweight, playful personal task manager. Segment size: `[TBD — needs data]`.
- **Revenue/business impact:** None planned. The product goal is personal growth, not revenue.
- **Competitive gap addressed:** The owner's stated gap is that existing tools are not "friendly and funny." Totogotchi addresses this with an always-visible pet whose state depends on task completion. No competitor analysis has been performed. `[TBD — needs data: review of Things, Reminders, Todoist, Habitica for macOS to confirm none offers an always-on-top pet-driven widget.]`

### 2.3 Proposed solution
A native macOS app that shows a small floating widget above other windows. The widget contains an animated pet and the current week's tasks. A global keyboard shortcut opens an inline field to capture a task in one step. The pet's mood is computed from completion rate, overdue count, and streak, giving immediate, playful feedback. All data stays on the local machine.

---

## 3. Users & User Stories

### 3.1 Primary personas

**Persona A — "Meeting Collector" (the owner, and the only validated persona)**
- **Goals:** Complete 100% of the week's tasks. Never lose a task captured in a meeting.
- **Motivations:** Personal discipline; enjoys playful software.
- **Current workflow:** Hears tasks in daily and weekly meetings → writes them somewhere ad hoc → prioritizes irregularly → some tasks are forgotten.
- **Pain points:** Capture is slow, list is not visible, no nudge when things slip.
- **Success looks like:** Every task captured in under five seconds during the meeting; week closes with the pet in "celebrating" state.

`[ASSUMPTION: Persona A is representative of the broader "everyone who requires task management" target. No other personas are validated; they are deferred until the owner has used the MVP for at least four weeks.]`

### 3.2 User journey

| Stage | Current state | Proposed future state | Opportunity |
|---|---|---|---|
| Capture | Switch to a notes/task app, type, switch back | Press global hotkey, type, Enter. Never leave the meeting app | Speed, no context loss |
| Prioritize | Irregular, manual | Set priority and due date at capture or in the list; week view sorts by due date then priority | Consistency |
| Track | List is hidden in another window | Widget is always on top; pet mood shows health at a glance | Visibility |
| Remind | None | macOS notification at due time; pet turns "worried" on overdue | Fewer forgotten tasks |
| Review | None | Sunday summary: completion %, streak, pet celebration | Motivation, metric capture |

### 3.3 Epics and user stories

#### Epic 1 — Quick capture

**Story 1.1:** As a Meeting Collector, I want to create a task with a global keyboard shortcut so that I can capture it without leaving my current app.
- **Acceptance criteria:**
  - Given any app is frontmost, when I press the configured global hotkey, then the widget's capture field is focused and ready for typing within 150 ms.
  - Given the capture field is focused, when I type text and press Enter, then a task is created with today's week as its default context and the field clears within 100 ms.
  - Given the capture field is focused, when I press Esc, then the field closes with no task created and focus returns to the previously frontmost app.
  - Given I type an empty or whitespace-only string, when I press Enter, then no task is created and the field shows an inline hint.
- **Priority:** Must
- **Dependencies:** Widget window (Epic 3); local persistence (Epic 5)

**Story 1.2:** As a Meeting Collector, I want to set due date and priority inline while capturing so that I do not need a second step.
- **Acceptance criteria:**
  - Given the capture field, when I type a token such as `!high`, `!med`, `!low`, `@today`, `@tomorrow`, `@fri`, then the token is removed from the title and applied as priority/due date.
  - Given no token is typed, when I press Enter, then the task defaults to priority Medium and due date = end of the current ISO week (Sunday 23:59 local).
  - Given an unrecognized token, when I press Enter, then it stays in the title unchanged.
- **Priority:** Should
- **Dependencies:** Story 1.1

#### Epic 2 — Task management

**Story 2.1:** As a Meeting Collector, I want to see this week's tasks in the widget sorted by due date and priority so that I know what to do next.
- **Acceptance criteria:**
  - Given tasks exist, when the widget is expanded, then it lists all not-done tasks with due date within the current ISO week plus all overdue not-done tasks, sorted by due date ascending then priority High → Low.
  - Given 1,000 stored tasks, when the list renders, then p95 render time is under 100 ms.
  - Given a task is overdue, when displayed, then it is visually distinct (color and icon, not color alone).
- **Priority:** Must
- **Dependencies:** Epic 5

**Story 2.2:** As a Meeting Collector, I want to mark a task done, edit it, or delete it so that the list stays accurate.
- **Acceptance criteria:**
  - Given a task row, when I click its checkbox or press Space with the row selected, then it is marked done, animates out within 300 ms, and the pet reacts (see Epic 4).
  - Given a task row, when I double-click the title, then it becomes editable inline; Enter saves, Esc cancels.
  - Given a task row, when I press Delete, then the task is removed and an "Undo" affordance is shown for 5 seconds.
  - Given a task was marked done by mistake, when I open "Completed" and uncheck it, then it returns to the list.
- **Priority:** Must
- **Dependencies:** Story 2.1

**Story 2.3:** As a Meeting Collector, I want tasks that recur weekly so that standing meeting actions are not retyped.
- **Priority:** Could
- **Dependencies:** Story 2.2
- **Acceptance criteria:** Given a task with a weekly recurrence, when I mark it done, then a new instance is created due the same weekday next week.

#### Epic 3 — Floating widget

**Story 3.1:** As a Meeting Collector, I want a small window that stays above other apps so that my tasks and pet are always visible.
- **Acceptance criteria:**
  - Given the app is running, when any other app is focused, then the widget remains visible above it (floating window level) on the active Space.
  - Given the widget, when I drag it, then it moves and its position persists across relaunches.
  - Given the widget, when I click the collapse control, then only the pet (≤ 120 × 120 pt) remains visible; clicking the pet expands it again.
  - Given macOS is in a full-screen app, when the widget is enabled for full-screen, then it still displays. `[ASSUMPTION: full-screen overlay is Could, not Must, because of macOS window-level constraints.]`
  - Given the app launches, when measured from click to first frame, then cold launch is under 1 second on an Apple Silicon Mac.
- **Priority:** Must
- **Dependencies:** None

#### Epic 4 — Pet

**Story 4.1:** As a Meeting Collector, I want the pet's mood to reflect my task progress so that I get playful feedback.
- **Acceptance criteria:**
  - Given the mood rules in §4.1.4, when task state changes, then the pet's displayed state updates within 500 ms.
  - Given I mark a task done, when the animation plays, then the pet performs a short (≤ 1.5 s) positive reaction.
  - Given the last task of the week is completed, when the state recalculates, then the pet enters "celebrating" and the widget shows the weekly summary (Story 6.1 if implemented; otherwise a simple banner).
  - Given the pet is in "sad" or "worried", when I hover over it, then a tooltip states the reason (e.g., "2 tasks overdue").
- **Priority:** Must
- **Dependencies:** Epics 2, 3, 5

**Story 4.2:** As a Meeting Collector, I want to name my pet and pick from a few looks so that it feels mine.
- **Priority:** Could
- **Dependencies:** Story 4.1

#### Epic 5 — Local persistence

**Story 5.1:** As a Meeting Collector, I want my tasks stored on my Mac only so that no account or network is needed.
- **Acceptance criteria:**
  - Given the app is quit or the Mac restarts, when I relaunch, then all tasks, pet state, and settings are restored with zero data loss.
  - Given the app is running, when network is disabled, then all features work identically.
  - Given the database file, when inspected, then it is inside the app's sandbox container.
  - Given a write operation, when measured, then p95 save latency is under 50 ms.
- **Priority:** Must
- **Dependencies:** None

#### Epic 6 — Reminders and review

**Story 6.1:** As a Meeting Collector, I want a notification when a task becomes due so that I do not forget it.
- **Acceptance criteria:**
  - Given a task with a due date and time, when the time arrives and the app is running, then a macOS notification appears within 60 seconds with the task title.
  - Given a notification, when I click it, then the widget expands with that task highlighted.
  - Given notification permission is denied, when a task becomes due, then the pet changes state but no OS notification is attempted and Settings shows how to re-enable.
- **Priority:** Must
- **Dependencies:** Epic 5

**Story 6.2:** As a Meeting Collector, I want a weekly summary so that I can see my completion rate and streak.
- **Acceptance criteria:** Given it is Sunday 20:00 local or the last task is completed, when the summary is shown, then it lists tasks due, completed, completion %, and current streak.
- **Priority:** Should
- **Dependencies:** Epic 5

---

## 4. Functional Requirements

### 4.1 Core features (Must-have)

#### 4.1.1 Quick capture
- **Description:** Global hotkey opens an inline text field in the widget; Enter creates a task.
- **Workflow:** Hotkey → type → Enter (or Esc to cancel).
- **Inputs/outputs:** Input: title (1–200 characters), optional tokens (§ Story 1.2). Output: Task record.
- **Business rules:** Default hotkey ⌥⌘T, user-configurable; must not conflict with system shortcuts. Titles trimmed; empty titles rejected.
- **Acceptance criteria:** Story 1.1.

#### 4.1.2 Task list (week view)
- **Description:** Expanded widget lists overdue and this-week tasks; done, edit, delete, undo.
- **Workflow:** See Stories 2.1, 2.2.
- **Inputs/outputs:** Task records → sorted list. User actions → state changes.
- **Business rules:** Week = ISO week, Monday–Sunday, local time zone. Done tasks leave the main list and appear in a "Completed" section for the current week. Priority values: High, Medium, Low.
- **Acceptance criteria:** Stories 2.1, 2.2.

#### 4.1.3 Floating widget
- **Description:** Always-on-top, draggable, collapsible panel.
- **Business rules:** Expanded default size 320 × 420 pt, collapsed ≤ 120 × 120 pt. Position, size, and collapse state persist. `[DECIDED 2026-09-06 (§11 row 7): agent-style app with no Dock icon; a small menu-bar item hosts Capture, Settings, Quit, and later Show Widget.]`
- **Acceptance criteria:** Story 3.1.

#### 4.1.4 Pet mood engine
- **Description:** Deterministic state machine that maps task data to one of five states.
- **Inputs:** completion rate for the current ISO week (C), count of overdue not-done tasks (O), consecutive days with at least one completion or zero tasks due (streak S).
- **Business rules (evaluated on every task change and every 15 minutes):**

| Condition (first match wins) | State |
|---|---|
| All tasks due this week are done and at least 1 task existed | Celebrating |
| O ≥ 3 | Sad |
| O ≥ 1 | Worried |
| C ≥ 0.5 or S ≥ 3 | Happy |
| Otherwise | Neutral |

- **Outputs:** state enum, reason string, transient reaction on completion.
- **Acceptance criteria:** Story 4.1. Additionally: given the table above, when unit-tested with each boundary (O = 0, 1, 3; C = 0.49, 0.5; S = 2, 3), then the expected state is returned.

#### 4.1.5 Reminders
- See Story 6.1. Business rule: one notification per task per due time; no repeat nagging in v1.

#### 4.1.6 Local persistence
- See Story 5.1 and §5.3.

### 4.2 Secondary features (Should / Could)

| Feature | Description | Value | Priority |
|---|---|---|---|
| Inline tokens for priority/due date | `!high`, `@fri` parsing at capture | Removes second step | Should |
| Weekly summary | Sunday review with completion %, streak | Captures the primary KPI; motivation | Should |
| Menu-bar item | Quit, Settings, Show/Hide widget | Needed for agent-style app | Should |
| Weekly recurring tasks | Auto-recreate on completion | Fewer retyped tasks | Could |
| Pet naming and skins | 2–3 looks, custom name | Attachment | Could |
| Full-screen overlay | Widget over full-screen apps | Visibility during presentations | Could |
| Tags / projects | Group tasks | Organization for heavier users | Could |
| Shortcuts.app action "Add task" | Automation entry point | Power users | Could |
| iCloud sync | Multi-Mac sync via CloudKit | Convenience | Could (v2) |

### 4.3 Out of scope (Won't — this release)
- iOS, iPadOS, Windows, web clients. Reason: platform constraint stated by owner.
- Shared or team lists, assignment, comments. Reason: single-user product.
- Calendar or Reminders.app integration. Reason: adds integration risk before core loop is validated.
- Cloud accounts, login, server backend. Reason: local-only requirement.
- Sub-tasks, attachments, natural-language date parsing beyond fixed tokens. Reason: scope control.
- Telemetry sent off-device. Reason: privacy; personal use.

### 4.4 Prioritization table

| Feature | MoSCoW | User value (1–5) | Business value (1–5) | Effort (S/M/L/XL) | Dependencies |
|---|---|---|---|---|---|
| Quick capture (hotkey) | Must | 5 | 5 | M | Widget, persistence |
| Task list week view | Must | 5 | 5 | M | Persistence |
| Done / edit / delete / undo | Must | 5 | 4 | S | Task list |
| Floating widget | Must | 5 | 5 | M | — |
| Pet mood engine | Must | 4 | 5 | M | Task list, widget |
| Pet animations (5 states) | Must | 4 | 5 | L | Mood engine, art assets |
| Local persistence | Must | 5 | 5 | S | — |
| Due notifications | Must | 4 | 3 | S | Persistence |
| Inline tokens | Should | 4 | 3 | S | Quick capture |
| Weekly summary | Should | 3 | 4 | S | Persistence |
| Menu-bar item | Should | 3 | 3 | S | — |
| Recurring tasks | Could | 3 | 2 | M | Done flow |
| Pet naming / skins | Could | 3 | 2 | M | Art assets |
| Full-screen overlay | Could | 2 | 1 | M | Widget |
| Tags / projects | Could | 2 | 2 | M | Task list |
| Shortcuts action | Could | 2 | 1 | S | Quick capture |
| iCloud sync | Could (v2) | 3 | 2 | L | Persistence |

---

## 5. Technical Requirements

### 5.1 Architecture
`[DECIDED 2026-09-06 (§11 row 8): Native Swift with SwiftUI and AppKit interop, SwiftData for persistence, minimum macOS 14 Sonoma. Chosen because a floating always-on-top window, global hotkeys, and notifications are first-class in AppKit, binary size is small, and idle CPU/memory are low. Alternatives considered: Electron (larger footprint, always-on-top and hotkeys possible but idle memory ≈ 100+ MB, contradicts "fast"); Tauri (Rust + web view; smaller than Electron but weaker native window-level control and less mature macOS APIs).]`

Components:
- **App shell (AppKit):** `NSPanel` at floating window level, non-activating, movable by background; menu-bar `NSStatusItem`; global hotkey registration.
- **UI layer (SwiftUI):** Widget views, capture field, task list, settings.
- **Domain layer:** `TaskStore`, `MoodEngine` (pure function of task data → state), `WeekCalendar` (ISO week math), `ReminderScheduler`.
- **Persistence:** SwiftData model container in the sandboxed Application Support directory.
- **Notifications:** `UserNotifications` framework.
- **Animation:** SwiftUI animations over sprite frames or Lottie-style vector assets. `[ASSUMPTION: sprite sheets in the app bundle; art source is TBD, see §11.]`

Data flow: user action → SwiftUI view → domain store mutation → SwiftData save → store publishes change → MoodEngine recomputes → views and `ReminderScheduler` update.

Integration points: macOS Notification Center only. No network.

### 5.2 API requirements
N/A — no server, no public API. Internal module boundaries are Swift protocols; the `MoodEngine` must be a pure function to allow unit testing. If the Shortcuts action (Could) is built, it uses the App Intents framework with a single `AddTaskIntent(title:priority:dueDate:)`.

### 5.3 Data requirements

**Data model**

| Entity | Fields | Constraints |
|---|---|---|
| Task | `id: UUID`, `title: String`, `notes: String?`, `priority: enum(high, medium, low)`, `dueDate: Date`, `createdAt: Date`, `completedAt: Date?`, `recurrence: enum(none, weekly)?`, `deletedAt: Date?` | title 1–200 chars; `dueDate` required; `completedAt ≤ now`; soft delete for undo |
| PetState | `name: String`, `skin: String`, `currentMood: enum`, `streakDays: Int`, `lastEvaluatedAt: Date` | single row |
| WeeklyStats | `isoYear: Int`, `isoWeek: Int`, `tasksDue: Int`, `tasksCompleted: Int`, `tasksDeleted: Int`, `tasksDeferred: Int` | unique (isoYear, isoWeek); written on week rollover |
| Settings | `hotkey: String`, `widgetFrame: CGRect`, `isCollapsed: Bool`, `notificationsEnabled: Bool` | single row |

- **Sources and integrations:** user input only.
- **Validation rules:** title trimmed and non-empty; `dueDate` must be a valid date; priority defaults to medium; moving a task to a later week increments `tasksDeferred` for the original week (guardrail, §8).
- **Privacy:** All data on-device inside the sandbox container. No analytics leave the device. Export to JSON available from Settings so the user owns their data. Deleting the app removes the container.

### 5.4 Performance specifications

| Metric | Target |
|---|---|
| Cold launch to first frame | < 1 s (Apple Silicon), < 2 s (Intel) |
| Hotkey to focused capture field | < 150 ms |
| Task create/complete to UI update | < 100 ms |
| List render, 1,000 tasks | p95 < 100 ms |
| Save latency | p95 < 50 ms |
| Idle CPU | < 1% average; animations pause when widget is occluded or display sleeps |
| Idle memory | < 80 MB resident |
| Capacity | 10,000 tasks without degrading the targets above |
| Availability | Local app; no uptime target. Crash-free sessions ≥ 99.5% |
| Growth | Personal use: ≈ 20–50 tasks per week; 10-year horizon ≈ 25,000 tasks; SwiftData with indexed `dueDate` handles this |

---

## 6. User Experience Requirements

### 6.1 Design principles
- **Glanceable:** the pet alone must communicate task health in under one second.
- **Zero friction capture:** never more than hotkey + text + Enter.
- **Playful, never punishing:** negative states are "worried" and "sad", with a tooltip explaining why and how to fix it. No guilt copy, no loss of progress.
- **Native feel:** follows Apple Human Interface Guidelines for macOS; supports light and dark appearance; respects "Reduce Motion".
- **Accessibility standard:** WCAG 2.2 AA equivalents via macOS Accessibility: full VoiceOver labels for tasks and pet state, keyboard-only operation of every action, contrast ≥ 4.5:1 for text, state never conveyed by color alone.

### 6.2 Interface requirements

**Key screens**
1. **Collapsed widget:** pet only (≤ 120 × 120 pt), small badge with count of overdue tasks if > 0. Click to expand.
2. **Expanded widget (320 × 420 pt default):** header with pet (≈ 100 pt tall) and week title ("Week 36 · 4 of 7 done"); capture field; list grouped as Overdue / This week / Completed (collapsed by default); footer with collapse button and settings gear.
3. **Capture state:** capture field focused, pet leans toward the field (idle-to-attentive animation).
4. **Settings (sheet):** hotkey recorder, notifications toggle, pet name/skin (if built), export JSON, launch at login.
5. **Weekly summary (Should):** overlay card with completion %, streak, celebration animation, "Start next week" button.

**Navigation and IA:** single window, no navigation stack. Everything reachable within two clicks or one shortcut.

**Interactive behaviors:** hover reveals row actions (edit, delete); Space toggles done; Delete removes with 5-second undo; drag widget by any non-interactive area; double-click title to edit.

**Responsive requirements:** widget resizable between 280 × 360 pt and 480 × 800 pt; list scrolls; pet scales proportionally. Must render correctly on Retina and non-Retina displays and across multiple monitors.

### 6.3 Usability criteria
- Task capture completed in ≤ 5 seconds from hotkey press in 95% of attempts (measured by owner self-timing over one week).
- First-run: user creates first task within 60 seconds of launch with no external documentation; a one-screen onboarding explains hotkey and pet moods.
- Satisfaction: `[TBD — needs data]`; with a single user, replace with a weekly self-rated 1–5 "did this help me" score, target ≥ 4.
- Error prevention and recovery: destructive actions are undoable for 5 seconds; empty titles blocked; hotkey conflicts detected and reported at assignment time.

---

## 7. Non-Functional Requirements

### 7.1 Security
- **Authentication/authorization:** N/A — single local user; macOS user account is the boundary.
- **Encryption:** data at rest protected by FileVault if the user has it enabled; the app does not add its own encryption in v1. `[ASSUMPTION: acceptable because data is non-sensitive personal tasks; revisit if notes field gets used for sensitive content.]`
- **Compliance:** N/A — no personal data leaves the device, no third parties. GDPR/HIPAA/SOC 2 do not apply.
- **Sandboxing:** App Sandbox enabled; entitlements limited to user notifications and, if App Store, none for network. Hardened Runtime and notarization required for distribution.
- **Security testing:** static analysis with Xcode warnings-as-errors; verify no network entitlement; verify export file is written only to a user-chosen location.

### 7.2 Performance
See §5.4. Additional: no network, so bandwidth is N/A. Database indexed on `dueDate` and `completedAt`.

### 7.3 Reliability
- Crash-free sessions ≥ 99.5%, measured locally via crash logs in Console.
- Zero data loss on quit, force-quit, or power loss: SwiftData saves are synchronous on mutation; WAL journaling enabled.
- Backup: user's Time Machine covers the container; Settings offers JSON export/import.
- Monitoring and alerting: N/A for external monitoring. Local `os_log` categories for capture, persistence, mood engine; owner reviews Console when something looks wrong.

### 7.4 Scalability
- User growth: N/A — one user per install; no shared infrastructure.
- Data volume: see §5.4 growth row.
- Geographic: N/A. Localization not planned in v1 (English UI). `[ASSUMPTION: English-only UI is acceptable; Spanish localization is a Could for v2.]`
- Infrastructure: none.

---

## 8. Success Metrics & Analytics

| Metric | Type | Baseline | Target | Timeframe | How measured |
|---|---|---|---|---|---|
| Weekly task completion rate (completed ÷ due in ISO week) | Primary | `[TBD — needs data: log 2 weeks manually before launch]` | 100% | Each week, reviewed Sunday; sustained for 4 consecutive weeks within 8 weeks of launch | `WeeklyStats` row, shown in weekly summary |
| Tasks captured via hotkey ÷ total tasks captured | Secondary | 0 (feature does not exist) | ≥ 80% | Weeks 1–4 | Local event log |
| Median time from hotkey to task saved | Secondary | N/A | ≤ 5 s | Weeks 1–4 | Timestamps in local event log |
| Overdue tasks at week end | Secondary | `[TBD — needs data]` | 0 | Weekly | `WeeklyStats` |
| Days per week app was running | Secondary | N/A | ≥ 5 | Weekly | Launch/quit log |
| Tasks deleted or deferred to next week ÷ tasks due | Guardrail | `[TBD — needs data]` | ≤ 10% | Weekly | `WeeklyStats.tasksDeleted + tasksDeferred` |
| Crash-free sessions | Guardrail | N/A | ≥ 99.5% | Rolling 4 weeks | Console crash logs |

Note on the primary target: 100% is the owner's stated goal. It is achievable only if the guardrail holds; otherwise the metric can be gamed by deleting or deferring tasks. The review decision uses both together.

**Analytics implementation**
- Events (local only, stored in a lightweight `EventLog` table, never transmitted): `task_created {source: hotkey|widget}`, `task_completed`, `task_deleted`, `task_deferred`, `capture_opened`, `capture_cancelled`, `mood_changed {from, to}`, `notification_shown`, `notification_clicked`, `app_launched`, `app_quit`.
- Dashboards: the in-app weekly summary is the dashboard. A "Stats" view showing the last 12 weeks is a Could.
- A/B testing: N/A — single user.
- Behavioral analytics tools: none; local SQL over the event table.

**Review cadence**
- Weekly, Sunday evening, by the owner: review primary KPI, guardrail, and overdue count.
- Every 4 weeks: decide iterate / expand / roll back. Roll back criteria: completion rate below the pre-launch baseline for 2 consecutive weeks, or guardrail exceeded for 2 consecutive weeks (means the pet is encouraging deletion rather than completion).

---

## 9. Implementation Plan

### 9.1 Development phases

**Phase 0 — Discovery (1 week)**
- Manually log tasks for baseline (§8). Sketch pet states on paper. Decide art source (§11). Spike: `NSPanel` floating window + global hotkey in a throwaway project.

**Phase 1 — MVP (≈ 4–5 weeks, part-time)**
Scope: all Must features in §4.1 with static (non-animated) pet images for the five states, plus menu-bar item (Should) because the app has no Dock icon.
Exit criteria: owner uses it daily for one full week; all Story acceptance criteria for Must items pass; performance targets in §5.4 met.

**Phase 2 — Delight (≈ 2 weeks)**
Animated pet states and completion reaction; inline tokens; weekly summary.

**Phase 3 — Iterate (ongoing)**
Based on 4-week review: recurring tasks, naming/skins, full-screen overlay, Shortcuts. iCloud sync only if a second Mac is in regular use.

**Release strategy:** direct download (notarized DMG) for personal use first. App Store submission is a later decision (§11). `[ASSUMPTION: direct distribution for v1.]`

### 9.2 Resource allocation
- Engineering: owner, ≈ 10 h/week.
- Design/UX: owner; pet art either self-made pixel art or a licensed asset pack (`[TBD]`).
- QA: owner, using the acceptance criteria in §3 as the test script plus unit tests for `MoodEngine` and `WeekCalendar`.
- DevOps/infrastructure: none; Xcode Cloud or local builds. Notarization requires an Apple Developer Program membership.

### 9.3 Timeline and milestones

| Milestone | Target | Definition | Status |
|---|---|---|---|
| M0 Discovery done | Week 1 | Baseline data collected, window/hotkey spike works, art source chosen | Partial. The window and hot-key spikes both work (§11 rows 7, 8 closed). Baseline logging (§11 row 2) and the art source (§11 row 9) are still open |
| M1 Capture + persistence | Week 3 | Stories 1.1, 5.1 pass | **Done 2026-09-06.** Change `add-task-capture-and-storage` archived; all 26 tasks verified |
| M2 Widget + list | Week 4 | Stories 2.1, 2.2, 3.1 pass | Not started. Change `add-floating-widget-and-task-list` |
| M3 Pet + reminders (MVP) | Week 6 | Stories 4.1, 6.1 pass; static pet images | Not started. Change `add-pet-mood-and-reminders`; blocked on §11 row 9 |
| M4 Dogfood week | Week 7 | Owner uses daily; bugs fixed | Not started |
| M5 Delight release | Week 9 | Animations, tokens, weekly summary | Not started. Change `add-delight-features` |
| M6 First 4-week review | Week 13 | Decide iterate / expand / roll back | Not started |

`[ASSUMPTION: week numbers assume ≈ 10 h/week starting the week of 2026-09-07.]`

---

## 10. Risks & Mitigation

| Risk | Category | Likelihood | Impact | Mitigation | Early warning signal | Owner |
|---|---|---|---|---|---|---|
| Floating window misbehaves across Spaces, full-screen apps, or multiple displays | Technical (architecture) | M | H | Phase 0 spike on `NSPanel` levels and collection behaviors; make full-screen overlay a Could | Spike takes > 3 days or needs private APIs | Owner |
| Global hotkey conflicts with system or other apps, or breaks under sandbox | Technical (integration) | M | M | Use documented event-tap-free API (`NSEvent` global monitor or Carbon `RegisterEventHotKey`); conflict detection UI; configurable default | Hotkey fails on first install | Owner |
| Animations raise idle CPU and battery drain | Technical (performance) | M | M | Pause animation when occluded or on battery low; cap at 30 fps; measure with Instruments before M5 | Idle CPU > 1% in Activity Monitor | Owner |
| Data loss on force-quit or crash | Technical (reliability) | L | H | Synchronous saves, WAL, JSON export; test with kill -9 | Any missing task after relaunch in dogfood | Owner |
| Security or privacy expectation mismatch if sensitive notes are stored | Technical (security) | L | M | Document local-only storage; FileVault reliance stated; revisit encryption if notes usage grows | Owner writes credentials or sensitive data in notes | Owner |
| The pet becomes annoying or guilt-inducing and the owner stops using the app | Business (adoption) | M | H | Non-punitive copy, "Reduce Motion" and "calm mode" toggle; 4-week review with roll-back criteria | App running < 5 days/week | Owner |
| Metric gamed by deleting or deferring tasks | Business (adoption) | M | M | Guardrail metric in §8; deferral counted explicitly | Guardrail > 10% | Owner |
| Existing apps already offer this; low market interest if ever distributed | Business (market) | M | L | Personal-use goal is not market-dependent; do competitor review before any public release | Competitor review finds a direct equivalent | Owner |
| Owner's time availability drops; project stalls | Business (resources) | H | M | Small MVP; static pet images before animation; milestones sized to ≈ 10 h/week | Two consecutive weeks with no commits | Owner |
| Pet art assets have license restrictions | Legal | L | M | Prefer self-made art or assets with explicit commercial-use license; record license in repo | License text unclear | Owner |
| App Store review rejects an always-on-top agent app | Legal / platform | L | L | Direct distribution for v1; App Store decision deferred | Rejection notice | Owner |

---

## 11. Open Questions & Assumptions

| # | Item | What is unknown | Why it matters | Who answers | By when |
|---|---|---|---|---|---|
| 1 | `[ASSUMPTION]` MVP effort 6–8 part-time weeks, no budget beyond Apple Developer account (§1) | Actual weekly hours available | Drives every milestone date in §9 | Owner | M0 |
| 2 | `[TBD]` Quantified impact of forgotten tasks; baseline completion rate (§2.1, §8) | How many tasks are captured, completed, forgotten per week today | Without a baseline the 100% target cannot show improvement | Owner, via 2 weeks of manual logging | Before M1 |
| 3 | `[TBD]` Market size, segment size, market timing (§1, §2.2) | No research done | Irrelevant for personal use; required before any public release | Owner | Before public release decision |
| 4 | `[TBD]` Competitor review (Things, Reminders, Todoist, Habitica) (§2.2) | Whether an equivalent always-on-top pet widget exists | Validates the differentiator | Owner | Before public release decision |
| 5 | `[ASSUMPTION]` Persona A represents the broader target (§3.1) | Whether other users share the same workflow | Feature priorities may shift for other personas | Owner, after 4 weeks of use | M6 |
| 6 | `[ASSUMPTION]` Full-screen overlay is Could, not Must (§3.3 Story 3.1) | Whether the owner needs the widget during presentations | Affects Phase 1 scope and window-level complexity | Owner | M0 |
| 7 | **DECIDED 2026-09-06** Agent-style app: no Dock icon; the menu-bar item hosts Capture, Settings and Quit (§4.1.3) | Resolved | Built and confirmed in change `add-task-capture-and-storage`: the running process reports `background only`, and the status item is the app's only chrome. Reversible by clearing `LSUIElement` | Owner | Closed |
| 8 | **DECIDED 2026-09-06** Swift 6 toolchain, SwiftUI with an AppKit shell, SwiftData, macOS 14+ (§5.1) | Resolved | Built and confirmed in change `add-task-capture-and-storage`. Measured against §5.4: press-to-focus 2–42 ms, save p95 3.66 ms at 10,000 tasks, idle CPU 0.00%, resident memory 68.6 MB | Owner | Closed |
| 9 | `[ASSUMPTION]` Sprite-sheet art bundled in app; art source TBD (§5.1, §9.2) | Self-made vs licensed asset pack; style | Drives Phase 2 effort and legal risk | Owner | M0 |
| 10 | `[ASSUMPTION]` No app-level encryption; FileVault is sufficient (§7.1) | Whether notes will hold sensitive content | Adds encryption work if wrong | Owner | M4 |
| 11 | `[ASSUMPTION]` English-only UI for v1 (§7.4) | Whether Spanish UI is wanted | Localization effort | Owner | M5 |
| 12 | `[TBD]` Satisfaction score method (§6.3) | Replaced by weekly self-rating ≥ 4/5 | Only proxy available with one user | Owner | M4 |
| 13 | `[ASSUMPTION]` Direct notarized DMG distribution for v1; App Store later (§9.1) | Whether App Store is a goal | Adds sandbox/entitlement review and $99/year program cost | Owner | M5 |
| 14 | `[ASSUMPTION]` Timeline assumes ≈ 10 h/week from 2026-09-07 (§9.3) | Real availability | All milestone dates | Owner | M0 |

**Sign-off:** Esau Ortega is the sole stakeholder and approves this document by changing Status to "Approved".
