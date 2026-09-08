# Pet Mood Specification

## Purpose

Turns the week's task data into a single, glanceable pet state so the user can tell in under a second whether they are on track, and get a playful nudge when they are not.

## Requirements

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

### Requirement: Motion when something happens
The system SHALL animate the pet when its mood changes, when a task is completed, and while the capture field is open, and MUST leave it still at all other times.

The pet does not loop an idle animation. Continuous motion in the widget's floating panel measured about 5% average CPU regardless of frame rate or artwork, which cannot be reconciled with the idle budget below.

#### Scenario: Mood change stirs the pet
- **WHEN** the mood changes from Neutral to Worried
- **THEN** the pet begins moving within 500 ms and settles back to stillness within 5 seconds

#### Scenario: Still when nothing is happening
- **WHEN** no mood change, completion or capture has occurred for 10 seconds
- **THEN** the pet is not moving

#### Scenario: Motion is distinct per mood
- **WHEN** the pet stirs in each of the five moods
- **THEN** each mood moves differently from the others

### Requirement: Animated reactions
The system SHALL play a completion reaction of at most 1.5 seconds when a task is completed and a celebration when the mood becomes Celebrating.

#### Scenario: Completion reaction
- **WHEN** the user completes a task
- **THEN** the reaction plays once and the pet returns to its computed mood within 1.5 seconds

#### Scenario: Celebration
- **WHEN** the mood becomes Celebrating
- **THEN** the celebrating pet is shown and moves

### Requirement: Attentive pose during capture
The system SHALL lean the pet towards the capture field while it is open and return it upright when the field closes.

#### Scenario: Capture opens and closes
- **WHEN** the user presses the capture hotkey and then presses Esc
- **THEN** the pet leans while the field is open and is upright after it closes

### Requirement: Animation respects Reduce Motion
The system MUST show static mood images and no reactions, celebrations or leaning when the user has enabled Reduce Motion.

#### Scenario: Reduce Motion on
- **WHEN** Reduce Motion is enabled and the user completes a task
- **THEN** the pet image changes to the new mood's static image with no movement

### Requirement: Animation pauses when not visible
The system MUST not animate while the widget is fully occluded, hidden, on an inactive Space, or the display is asleep, and SHALL resume within 500 ms of becoming visible.

#### Scenario: Occluded by another window
- **WHEN** another window fully covers the widget while the pet is moving
- **THEN** the motion stops and resumes within 500 ms of the widget being uncovered

### Requirement: Idle CPU budget
The system SHALL keep average CPU usage below 1% while the widget is visible and no mood change, completion or capture has occurred.

#### Scenario: Idle CPU measurement
- **WHEN** the widget is visible, no user interaction occurs for 5 minutes, and CPU usage is sampled
- **THEN** the average is below 1%
