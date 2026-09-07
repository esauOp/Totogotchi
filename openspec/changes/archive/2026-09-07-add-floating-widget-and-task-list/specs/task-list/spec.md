## Purpose

Shows the user exactly which tasks matter this week, in the right order, and lets them complete, correct or remove tasks from the widget with the mouse or the keyboard.

## ADDED Requirements

### Requirement: Week view contents
The system SHALL list every not-completed, not-deleted task whose due date is within the current ISO week, plus every not-completed, not-deleted task whose due date is earlier than now, grouped as Overdue and This Week.

#### Scenario: Task due next week hidden
- **WHEN** a task is due on the Monday after the current ISO week ends
- **THEN** it does not appear in the list

#### Scenario: Overdue from a previous week shown
- **WHEN** a task due two weeks ago is still not completed
- **THEN** it appears in the Overdue group

#### Scenario: Week rollover
- **WHEN** the local clock passes Sunday 23:59 into Monday
- **THEN** the list updates within 60 seconds to show the new week's tasks and moves any unfinished tasks to Overdue

### Requirement: Sort order
The system SHALL sort tasks within each group by due date ascending and, for equal due dates, by priority high, then medium, then low.

#### Scenario: Same due date different priority
- **WHEN** three tasks are due Friday with priorities low, high and medium
- **THEN** they appear in the order high, medium, low

### Requirement: Overdue tasks are visually distinct
The system MUST mark overdue tasks with both a color and an icon so the state is not conveyed by color alone.

#### Scenario: Overdue marker
- **WHEN** a task's due date has passed
- **THEN** its row shows an overdue icon and a distinct color, and VoiceOver reads "overdue" as part of the row label

### Requirement: Complete and uncomplete
The system SHALL mark a task complete when the user clicks its checkbox or presses Space with the row selected, MUST move it to the Completed group within 300 ms, and SHALL let the user uncomplete it from that group.

#### Scenario: Complete with keyboard
- **WHEN** a row is selected and the user presses Space
- **THEN** the task is completed and leaves the active list within 300 ms

#### Scenario: Undo a mistaken completion
- **WHEN** the user expands the Completed group and unchecks a task
- **THEN** the task returns to its original group with its completion timestamp cleared

#### Scenario: Completed group collapsed by default
- **WHEN** the widget is shown
- **THEN** the Completed group is collapsed and shows the count of tasks completed this week

### Requirement: Inline edit
The system SHALL let the user edit a task title in place by double-clicking it or pressing Enter with the row selected, saving on Enter and cancelling on Esc.

#### Scenario: Save edit
- **WHEN** the user double-clicks a title, changes it to "Book flights", and presses Enter
- **THEN** the task title is "Book flights" and the row leaves edit mode

#### Scenario: Cancel edit
- **WHEN** the user is editing a title and presses Esc
- **THEN** the original title is kept

#### Scenario: Invalid edit
- **WHEN** the user clears the title and presses Enter
- **THEN** the edit is refused with an inline hint and the original title is kept

### Requirement: Delete with undo
The system SHALL delete a task when the user presses Delete with the row selected or uses the row's delete action, and MUST offer an Undo control for 5 seconds that restores the task.

#### Scenario: Delete and undo
- **WHEN** the user deletes a task and clicks Undo within 5 seconds
- **THEN** the task reappears in its original position

#### Scenario: Undo expires
- **WHEN** 5 seconds pass after a delete without Undo being used
- **THEN** the Undo control disappears and the task stays deleted

### Requirement: Keyboard operation
The system MUST allow selecting rows with the arrow keys and performing every list action without a pointing device.

#### Scenario: Navigate and act by keyboard
- **WHEN** the widget has focus and the user presses Down twice, then Space
- **THEN** the third task in the list is completed

### Requirement: List rendering performance
The system SHALL render the week view within 100 ms at the 95th percentile when 1,000 tasks are stored.

#### Scenario: Render under load
- **WHEN** 1,000 tasks are stored, 60 of them due this week, and the list is rendered 50 times
- **THEN** at least 48 renders complete in under 100 ms
