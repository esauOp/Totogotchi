## Purpose

Turns the week's task data into a single, glanceable pet state so the user can tell in under a second whether they are on track, and get a playful nudge when they are not.

## ADDED Requirements

### Requirement: Mood inputs
The system SHALL compute the pet's mood from three inputs: the completion rate C for the current ISO week (completed tasks due this week divided by all tasks due this week), the count O of overdue not-completed tasks, and the streak S of consecutive days on which the user completed at least one task or had no task due.

#### Scenario: Completion rate with no tasks
- **WHEN** no tasks are due in the current week
- **THEN** C is treated as 0 and the "all tasks done" condition is not met

#### Scenario: Streak counts empty days
- **WHEN** the user completed a task on Monday, had no tasks due on Tuesday, and completed a task on Wednesday
- **THEN** S is 3 on Wednesday

#### Scenario: Streak breaks
- **WHEN** a day ends with at least one task due that day still not completed and no task completed that day
- **THEN** S resets to 0

### Requirement: Mood rules
The system SHALL choose the mood by evaluating these rules in order and taking the first that matches: Celebrating when every task due this week is completed and at least one task was due; Sad when O is 3 or more; Worried when O is 1 or more; Happy when C is at least 0.5 or S is at least 3; otherwise Neutral.

#### Scenario: Celebrating wins over overdue rules
- **WHEN** all 5 tasks due this week are completed and O is 0
- **THEN** the mood is Celebrating

#### Scenario: Overdue boundary at three
- **WHEN** O is 3 and C is 0.9
- **THEN** the mood is Sad

#### Scenario: Overdue boundary at one
- **WHEN** O is 1 and C is 0.9
- **THEN** the mood is Worried

#### Scenario: Zero overdue, half done
- **WHEN** O is 0, C is 0.5 and S is 0
- **THEN** the mood is Happy

#### Scenario: Just under half
- **WHEN** O is 0, C is 0.49 and S is 2
- **THEN** the mood is Neutral

#### Scenario: Streak carries the mood
- **WHEN** O is 0, C is 0.2 and S is 3
- **THEN** the mood is Happy

### Requirement: Evaluation timing
The system SHALL re-evaluate the mood within 500 ms of any task creation, completion, edit, deletion or undo, and at least every 15 minutes while running.

#### Scenario: Completing a task updates the pet
- **WHEN** the user completes the last overdue task
- **THEN** the pet leaves the Worried state within 500 ms

#### Scenario: Time-based change with no user action
- **WHEN** a task's due time passes while the user is idle
- **THEN** the pet reflects the new overdue count within 15 minutes

### Requirement: One image per mood
The system SHALL display a distinct pet image for each of the five moods and MUST expose the mood name to assistive technology.

#### Scenario: VoiceOver reads the mood
- **WHEN** VoiceOver focuses the pet while the mood is Worried
- **THEN** it reads a label that includes "Worried" and the reason text

### Requirement: Reason on hover
The system SHALL show a tooltip explaining the current mood when the user hovers over the pet, and MUST use encouraging, non-blaming wording.

#### Scenario: Worried reason
- **WHEN** the mood is Worried because 2 tasks are overdue and the user hovers over the pet
- **THEN** a tooltip appears containing "2 tasks overdue" and a hint about how to fix it

#### Scenario: Happy reason
- **WHEN** the mood is Happy and the user hovers over the pet
- **THEN** a tooltip appears stating the completion rate or streak that earned it

### Requirement: Completion reaction
The system SHALL show a brief positive reaction from the pet when a task is completed, lasting no longer than 1.5 seconds, after which the pet returns to its computed mood.

#### Scenario: Reaction then settle
- **WHEN** the user completes a task while the mood is Neutral
- **THEN** a positive reaction image is shown for at most 1.5 seconds and the pet then shows the recomputed mood

### Requirement: Weekly completion banner
The system SHALL show a banner in the widget when the mood becomes Celebrating.

#### Scenario: Last task done
- **WHEN** the user completes the final task due this week
- **THEN** the pet enters Celebrating and a banner congratulating the user appears in the widget until dismissed or the week rolls over
