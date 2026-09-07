## Purpose

Provides the small always-on-top window that keeps the pet and the week's tasks permanently visible while the user works in other applications.

## ADDED Requirements

### Requirement: Widget stays above other windows
The system SHALL display the widget in a window that remains visible above the windows of other applications on the active Space while the app is running.

#### Scenario: Another app is focused
- **WHEN** the user activates a different application and brings its window to the front
- **THEN** the widget remains fully visible above that window

#### Scenario: Switching Spaces
- **WHEN** the user switches to a different Space
- **THEN** the widget is visible on the new Space at the same screen position

### Requirement: Draggable with persisted frame
The system SHALL let the user drag the widget by any non-interactive area and MUST restore its position and size on the next launch.

#### Scenario: Position persists
- **WHEN** the user drags the widget to the bottom-right corner, quits, and relaunches
- **THEN** the widget appears at the bottom-right corner

#### Scenario: Display no longer present
- **WHEN** the persisted frame lies on a display that is not connected at launch
- **THEN** the widget appears fully on the main display

### Requirement: Resizable within bounds
The system SHALL allow resizing the expanded widget between 280 by 360 points and 480 by 800 points and MUST default to 320 by 420 points on first launch.

#### Scenario: Resize below minimum
- **WHEN** the user drags the widget edge to make it smaller than 280 by 360 points
- **THEN** the widget stops at 280 by 360 points

#### Scenario: Content adapts
- **WHEN** the widget is resized
- **THEN** the task list scrolls within the available height and the pet image scales proportionally without clipping

### Requirement: Collapse to pet only
The system SHALL collapse the widget to a pet-only view no larger than 120 by 120 points and MUST expand it again when the pet is clicked.

#### Scenario: Collapse
- **WHEN** the user clicks the collapse control
- **THEN** only the pet is visible within a 120 by 120 point area and the collapsed state persists across relaunch

#### Scenario: Expand
- **WHEN** the widget is collapsed and the user clicks the pet
- **THEN** the widget returns to its previous expanded size and position

#### Scenario: Overdue badge when collapsed
- **WHEN** the widget is collapsed and at least one task is overdue
- **THEN** a badge with the overdue count is shown next to the pet, and it is hidden when the count is zero

### Requirement: Launch performance
The system SHALL show the widget's first frame within 1 second of launch on an Apple Silicon Mac and within 2 seconds on an Intel Mac.

#### Scenario: Cold launch
- **WHEN** the app is launched from a cold start with 1,000 stored tasks
- **THEN** the widget is drawn within 1 second on Apple Silicon

### Requirement: Appearance and motion preferences
The system MUST render correctly in light and dark appearance and MUST disable non-essential animation when the user has enabled Reduce Motion.

#### Scenario: Dark mode
- **WHEN** the system appearance switches to dark
- **THEN** the widget updates its colors without relaunch and all text keeps a contrast ratio of at least 4.5 to 1

#### Scenario: Reduce Motion
- **WHEN** Reduce Motion is enabled and the widget collapses or expands
- **THEN** the transition completes without animated movement
