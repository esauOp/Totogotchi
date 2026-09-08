## ADDED Requirements

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
