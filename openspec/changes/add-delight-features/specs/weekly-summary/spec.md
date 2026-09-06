## Purpose

Shows the user how the week went, in numbers and with a celebration, so the primary success metric is visible where the work happens instead of hidden in a database.

## ADDED Requirements

### Requirement: Summary trigger
The system SHALL show the weekly summary card in the widget at 20:00 local time on Sunday, or earlier when the mood becomes Celebrating, and MUST show it at most once per ISO week unless the user reopens it.

#### Scenario: Sunday evening
- **WHEN** the local clock reaches Sunday 20:00 and the summary has not been shown this week
- **THEN** the summary card appears over the task list

#### Scenario: Early completion
- **WHEN** the user completes the last task due this week on Thursday
- **THEN** the summary card appears and does not appear again automatically on Sunday

#### Scenario: Reopen from menu
- **WHEN** the user chooses This Week's Summary from the status item menu
- **THEN** the summary card appears with the current figures

### Requirement: Summary contents
The system SHALL display the number of tasks due this week, the number completed, the completion rate as a percentage, the current streak in days, and the number of tasks deleted or moved to a later week.

#### Scenario: Figures match the data
- **WHEN** 8 tasks were due, 7 completed, 1 deleted, 0 deferred and the streak is 5
- **THEN** the card shows 8 due, 7 completed, 88%, 5-day streak, and 1 deleted or deferred

#### Scenario: Empty week
- **WHEN** no tasks were due this week
- **THEN** the card shows 0 due and a neutral message instead of a percentage

### Requirement: Deferral counts toward the guardrail
The system MUST count a task as deferred for the original week when its due date is moved from the current ISO week to a later week.

#### Scenario: Move task to next week
- **WHEN** a task due this Friday is edited to be due next Tuesday
- **THEN** this week's deferred count increases by 1 and next week's due count increases by 1

### Requirement: Weekly statistics are kept
The system SHALL store one statistics record per ISO week containing due, completed, deleted and deferred counts, written when the week rolls over, and SHALL keep at least 52 weeks of records.

#### Scenario: Rollover writes the record
- **WHEN** the local clock passes from Sunday to Monday
- **THEN** a record for the finished week exists with the final counts and a new week starts at zero

### Requirement: Dismiss and start next week
The system SHALL let the user dismiss the card, and after Sunday 20:00 SHALL offer a Start Next Week action that hides the card and shows the upcoming week's tasks.

#### Scenario: Dismiss
- **WHEN** the user clicks Dismiss on the card
- **THEN** the card closes and the task list is visible again
