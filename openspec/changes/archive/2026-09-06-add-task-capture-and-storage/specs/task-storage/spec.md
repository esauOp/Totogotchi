## Purpose

Defines the task record, its validation rules, and the on-device persistence guarantees every other Totogotchi capability depends on. Data never leaves the user's Mac.

## ADDED Requirements

### Requirement: Task record fields
The system SHALL store each task with a unique identifier, a title, optional notes, a priority of high, medium or low, a due date, a creation timestamp, an optional completion timestamp, an optional weekly recurrence flag, and an optional deletion timestamp.

#### Scenario: New task has defaults
- **WHEN** a task is created with only a title
- **THEN** its priority is medium, its due date is Sunday 23:59 local time of the current ISO week, its creation timestamp is now, and completion, recurrence and deletion are unset

#### Scenario: Completion timestamp is never in the future
- **WHEN** a task is marked complete
- **THEN** its completion timestamp equals the current time and cannot be set to a later time

### Requirement: Title validation
The system SHALL trim surrounding whitespace from a title and MUST reject titles that are empty after trimming or longer than 200 characters.

#### Scenario: Whitespace-only title rejected
- **WHEN** a task is saved with a title consisting only of spaces or tabs
- **THEN** the save is refused with a validation error and no task is stored

#### Scenario: Title trimmed
- **WHEN** a task is saved with the title "  Call dentist  "
- **THEN** the stored title is "Call dentist"

#### Scenario: Over-long title rejected
- **WHEN** a task is saved with a title of 201 characters
- **THEN** the save is refused with a validation error naming the 200-character limit

### Requirement: Soft delete with undo window
The system SHALL delete tasks by setting a deletion timestamp and MUST allow the deletion to be reversed for at least 5 seconds.

#### Scenario: Deleted task is hidden but recoverable
- **WHEN** a task is deleted
- **THEN** it no longer appears in any task query and an undo operation restores it with all fields intact for at least 5 seconds

#### Scenario: Deleted tasks are purged
- **WHEN** a task has carried a deletion timestamp for more than 30 days
- **THEN** it is permanently removed from storage

### Requirement: Durable on-device storage
The system SHALL persist every task mutation to local storage inside the app's sandbox container before reporting success, and MUST restore all tasks unchanged after quit, force-quit, or restart.

#### Scenario: Restore after normal relaunch
- **WHEN** the app is quit and relaunched
- **THEN** every task, including completed and soft-deleted ones within the undo window, is present with identical field values

#### Scenario: Restore after forced termination
- **WHEN** the app process is killed immediately after a task is created and the app is relaunched
- **THEN** the created task is present

#### Scenario: Storage lives in the sandbox
- **WHEN** the storage location is inspected
- **THEN** all files are inside the app's sandbox container directory and no files are written elsewhere

### Requirement: Offline operation
The system MUST provide all storage operations without network access.

#### Scenario: Network disabled
- **WHEN** the Mac has no network connection and a task is created, edited, completed and deleted
- **THEN** every operation succeeds identically to when the network is available

### Requirement: Save latency
The system SHALL complete a single task save within 50 ms at the 95th percentile on a Mac with 10,000 stored tasks.

#### Scenario: Save under load
- **WHEN** 10,000 tasks exist and 100 consecutive single-task saves are timed
- **THEN** at least 95 of them complete in under 50 ms

### Requirement: JSON export and import
The system SHALL export all tasks to a JSON file at a user-chosen location and MUST import a file it previously exported without data loss.

#### Scenario: Export round-trip
- **WHEN** the user exports tasks to a file and imports that file into an empty store
- **THEN** the resulting tasks match the originals field by field

#### Scenario: Export writes only where chosen
- **WHEN** the user exports
- **THEN** exactly one file is written, at the location the user selected, and nothing is written elsewhere
