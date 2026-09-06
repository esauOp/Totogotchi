## Purpose

Makes sure a task with a due time is brought to the user's attention when that time arrives, even when the widget is hidden or collapsed.

## ADDED Requirements

### Requirement: Notification at due time
The system SHALL post a system notification containing the task title within 60 seconds of a task's due date and time while the app is running and notifications are permitted.

#### Scenario: Due time reached
- **WHEN** a task is due at 14:00 and the clock reaches 14:00 with the app running
- **THEN** a notification with the task title is shown by 14:01

#### Scenario: Due time passed while app was not running
- **WHEN** the app launches and finds tasks whose due time passed while it was not running and that have not been notified
- **THEN** it posts one notification summarizing how many tasks became due, not one per task

### Requirement: One notification per task per due time
The system MUST post at most one notification for a given task and due time.

#### Scenario: No repeat
- **WHEN** a task's due time passed and it was notified, and the app keeps running for another hour
- **THEN** no further notification for that task is posted

#### Scenario: Due date changed
- **WHEN** the user moves a notified task's due date to a later time
- **THEN** a new notification is posted when the new due time arrives

### Requirement: Notification opens the task
The system SHALL expand the widget and highlight the corresponding task when the user clicks a notification.

#### Scenario: Click notification
- **WHEN** the user clicks the notification for "Send weekly report"
- **THEN** the widget is shown and expanded with that task's row highlighted and scrolled into view

### Requirement: Permission handling
The system SHALL request notification permission the first time a task with a due time is created, and MUST keep all other behavior working when permission is denied.

#### Scenario: Permission denied
- **WHEN** notification permission is denied and a task becomes due
- **THEN** no notification is attempted, the pet mood still updates, and Settings shows how to enable notifications in System Settings

#### Scenario: Permission granted later
- **WHEN** the user enables notifications in System Settings after denying them
- **THEN** the next task to become due produces a notification without relaunching the app

### Requirement: Notifications toggle
The system SHALL let the user turn task notifications off in Settings independently of the system permission.

#### Scenario: Toggle off
- **WHEN** the user turns notifications off in Settings and a task becomes due
- **THEN** no notification is posted and the pet mood still updates
