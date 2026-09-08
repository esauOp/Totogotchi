# Usage Log Specification

## Purpose

Records how the app is used, on the device only, so the owner can measure the PRD success metrics without any telemetry leaving the Mac.

## Requirements

### Requirement: Events recorded
The system SHALL record a timestamped event for each of: task created with its source (hotkey or widget), task completed, task deleted, task deferred, capture opened, capture cancelled, mood changed with previous and new mood, notification shown, notification clicked, app launched, and app quit.

#### Scenario: Capture via hotkey
- **WHEN** the user creates a task from the capture field opened by the hotkey
- **THEN** a "task created" event with source "hotkey" and the task identifier is recorded

#### Scenario: Mood change
- **WHEN** the mood changes from Neutral to Happy
- **THEN** a "mood changed" event with previous "Neutral" and new "Happy" is recorded

### Requirement: Events never leave the device
The system MUST store events only inside the app's sandbox container and MUST NOT transmit them over any network.

#### Scenario: No network activity
- **WHEN** the app runs for a full day with all features used
- **THEN** it makes no outbound network connections

### Requirement: Event content excludes task text
The system MUST NOT store task titles or notes in event records, only identifiers.

#### Scenario: Inspect an event
- **WHEN** a recorded "task created" event is inspected
- **THEN** it contains the task identifier and source but not the title

### Requirement: Retention
The system SHALL keep at least 90 days of events and MAY delete older events.

#### Scenario: Old events purged
- **WHEN** events older than 90 days exist at launch
- **THEN** they may be removed while all events from the last 90 days remain

### Requirement: Export with tasks
The system SHALL include usage events and weekly statistics in the JSON export.

#### Scenario: Export contains events
- **WHEN** the user exports data
- **THEN** the exported file contains the tasks, weekly statistics, and usage events
