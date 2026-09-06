## ADDED Requirements

### Requirement: Animated mood states
The system SHALL play a distinct looping idle animation for each of the five moods in place of the static image.

#### Scenario: Mood change swaps animation
- **WHEN** the mood changes from Neutral to Worried
- **THEN** the Worried idle animation is playing within 500 ms of the change

### Requirement: Animated reactions
The system SHALL play a completion reaction of at most 1.5 seconds when a task is completed and a celebration animation when the mood becomes Celebrating.

#### Scenario: Completion reaction
- **WHEN** the user completes a task
- **THEN** the reaction animation plays once and the current mood's idle animation resumes within 1.5 seconds

#### Scenario: Celebration
- **WHEN** the mood becomes Celebrating
- **THEN** the celebration animation plays once and the Celebrating idle animation follows

### Requirement: Attentive pose during capture
The system SHALL switch the pet to an attentive pose while the capture field is open and return to the mood idle when it closes.

#### Scenario: Capture opens and closes
- **WHEN** the user presses the capture hotkey and then presses Esc
- **THEN** the pet shows the attentive pose while the field is open and the mood idle after it closes

### Requirement: Animation respects Reduce Motion
The system MUST show static mood images and no reactions or celebrations when the user has enabled Reduce Motion.

#### Scenario: Reduce Motion on
- **WHEN** Reduce Motion is enabled and the user completes a task
- **THEN** the pet image changes to the new mood's static image with no movement

### Requirement: Animation pauses when not visible
The system MUST pause all pet animation while the widget is fully occluded, hidden, on an inactive Space, or the display is asleep, and SHALL resume within 500 ms of becoming visible.

#### Scenario: Occluded by another window
- **WHEN** another window fully covers the widget for 10 seconds
- **THEN** animation is paused during that time and resumes within 500 ms of the widget being uncovered

### Requirement: Animation CPU budget
The system SHALL keep average CPU usage below 1% while the widget is visible and idle with animations playing.

#### Scenario: Idle CPU measurement
- **WHEN** the widget is visible, no user interaction occurs for 5 minutes, and CPU usage is sampled
- **THEN** the average is below 1% and the frame rate does not exceed 30 frames per second
