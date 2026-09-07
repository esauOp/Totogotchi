# Menu Bar Item Specification

## Purpose

Gives an app with no Dock icon a permanent, discoverable place in the menu bar to show or hide the widget, open Settings, and quit.

## Requirements

### Requirement: Status item is always present
The system SHALL show a status item in the menu bar whenever the app is running.

#### Scenario: Visible after launch
- **WHEN** the app finishes launching
- **THEN** a Totogotchi icon is present in the menu bar

### Requirement: Menu actions
The system SHALL offer Show Widget or Hide Widget, Settings, and Quit in the status item menu.

#### Scenario: Hide and show widget
- **WHEN** the user chooses Hide Widget and then Show Widget
- **THEN** the widget disappears and then reappears at its previous frame and collapse state

#### Scenario: Open Settings
- **WHEN** the user chooses Settings
- **THEN** the Settings window opens and becomes frontmost

#### Scenario: Quit
- **WHEN** the user chooses Quit
- **THEN** all pending saves complete and the app exits

### Requirement: Overdue indicator
The system SHALL reflect overdue tasks in the status item when the widget is hidden.

#### Scenario: Widget hidden with overdue tasks
- **WHEN** the widget is hidden and at least one task is overdue
- **THEN** the status item shows an overdue indicator, and it is removed when no task is overdue
