## Why

The MVP works but the pet is static, capture needs a second step to set priority or date, and the primary KPI (weekly completion rate, PRD §8) is not yet visible to the user. This change is PRD Phase 2 "Delight" and milestone M5 (§9.1, §9.3). It implements Stories 1.2 and 6.2, the animated pet states from §4.4, and the local event log that §8 requires for measuring success.

## What Changes

- Add inline tokens at capture so `!high`, `!med`, `!low`, `@today`, `@tomorrow` and weekday tokens like `@fri` set priority and due date without leaving the field.
- Animate the pet: idle loops per mood, a completion reaction, a celebration, an attentive pose while capturing, with Reduce Motion and occlusion handling to protect the idle CPU budget.
- Add the weekly summary card shown on Sunday evening or when the week is fully completed, reporting tasks due, completed, completion rate, streak and the guardrail counts of deleted and deferred tasks.
- Add a local-only usage log of the events listed in PRD §8 and the weekly statistics record that backs the summary.

Non-goals for this change:
- Recurring tasks, pet naming and skins, full-screen overlay, tags, Shortcuts action, iCloud sync (PRD Could and §4.3).
- Any transmission of usage data off the device (PRD §4.3).
- Natural-language date parsing beyond the fixed token list (PRD §4.3).

## Capabilities

### New Capabilities
- `weekly-summary`: the end-of-week report, when it appears, and what it contains.
- `usage-log`: which events are recorded locally, what they contain, and the guarantee that they never leave the device.

### Modified Capabilities
- `quick-capture`: adds token parsing for priority and due date at capture time. Existing capture behavior is unchanged; the additions are new requirements.
- `pet-mood`: adds animated states, motion and occlusion rules, and the capture-attentive pose. Mood rules are unchanged.

## Impact

- Depends on `add-pet-mood-and-reminders` being archived.
- Adds WeeklyStats and EventLog persistence; the week-rollover job writes one WeeklyStats row per ISO week.
- Needs animated art for five moods plus reaction, celebration and attentive poses; extends the PRD §11 row 9 art decision.
- Exercises PRD §10 row 3 (animation CPU and battery) and row 7 (metric gaming, via the guardrail counts in the summary).
