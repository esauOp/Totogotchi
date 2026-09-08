# Quick Capture Specification

## Purpose

Lets the user create a task from any application with a single global keyboard shortcut, so a task heard in a meeting is captured in seconds without switching context.

## Requirements

### Requirement: Global hotkey opens capture field
The system SHALL register a system-wide keyboard shortcut that, when pressed while any application is frontmost, presents a capture text field with keyboard focus within 150 ms.

#### Scenario: Hotkey from another app
- **WHEN** a different application is frontmost and the user presses the configured hotkey
- **THEN** the capture field appears with keyboard focus in under 150 ms and typed characters go into it

#### Scenario: Hotkey while capture already open
- **WHEN** the capture field is already open and the hotkey is pressed again
- **THEN** the field keeps focus and its current text is preserved

### Requirement: Enter creates a task
The system SHALL create a task from the capture field's text when the user presses Enter, and MUST clear the field within 100 ms of the keypress.

#### Scenario: Successful capture
- **WHEN** the user types "Send weekly report" and presses Enter
- **THEN** a task titled "Send weekly report" exists with default priority and due date, and the field is empty within 100 ms

#### Scenario: Empty capture rejected
- **WHEN** the field is empty or contains only whitespace and the user presses Enter
- **THEN** no task is created and an inline hint asks for a title

#### Scenario: Over-long capture rejected
- **WHEN** the field contains more than 200 characters and the user presses Enter
- **THEN** no task is created, the text remains in the field, and an inline hint shows the character limit

### Requirement: Esc cancels capture
The system SHALL close the capture field when the user presses Esc, MUST discard any typed text, and MUST return keyboard focus to the application that was frontmost before the hotkey.

#### Scenario: Cancel returns focus
- **WHEN** the user presses the hotkey from a text editor, types "draft", and presses Esc
- **THEN** no task is created, the capture field closes, and the text editor is frontmost again with its previous focus

### Requirement: Configurable hotkey with default
The system SHALL use Option-Command-T as the default hotkey and MUST let the user record a different shortcut in Settings.

#### Scenario: First launch default
- **WHEN** the app runs for the first time
- **THEN** pressing Option-Command-T opens the capture field

#### Scenario: Custom hotkey persists
- **WHEN** the user records Control-Shift-Space as the hotkey and relaunches the app
- **THEN** Control-Shift-Space opens the capture field and Option-Command-T does not

### Requirement: Hotkey conflict detection
The system MUST detect when the chosen shortcut cannot be registered and SHALL tell the user at assignment time.

#### Scenario: Shortcut unavailable
- **WHEN** the user records a shortcut that the system refuses to register
- **THEN** the previous hotkey remains active and Settings shows a message that the shortcut is unavailable

#### Scenario: Registration fails at launch
- **WHEN** the saved hotkey cannot be registered at launch
- **THEN** the app falls back to the default hotkey and shows a one-time notice explaining the fallback

### Requirement: Capture is available without the widget
The system SHALL allow capture to work even when no task list or widget window is visible.

#### Scenario: Capture with all windows hidden
- **WHEN** no Totogotchi window is visible and the hotkey is pressed
- **THEN** the capture field appears and a task can be created

### Requirement: Priority tokens
The system SHALL interpret the tokens `!high`, `!med` and `!low` anywhere in the capture text as the task priority, MUST remove the token from the stored title, and SHALL use the last such token when more than one is present.

#### Scenario: Priority token applied
- **WHEN** the user captures "Renew passport !high"
- **THEN** a task titled "Renew passport" is created with priority high

#### Scenario: Multiple priority tokens
- **WHEN** the user captures "!low Fix bug !high"
- **THEN** the task title is "Fix bug" and its priority is high

### Requirement: Due date tokens
The system SHALL interpret `@today`, `@tomorrow`, and weekday tokens `@mon` through `@sun` as the due date, MUST remove the token from the stored title, and SHALL resolve a weekday token to the next occurrence of that weekday including today.

#### Scenario: Today token
- **WHEN** the user captures "Call bank @today"
- **THEN** the task is due today at 23:59 local time

#### Scenario: Weekday token resolves forward
- **WHEN** today is Wednesday and the user captures "Prepare demo @fri"
- **THEN** the task is due this Friday at 23:59 local time

#### Scenario: Weekday token on the same day
- **WHEN** today is Friday and the user captures "Submit report @fri"
- **THEN** the task is due today at 23:59 local time

#### Scenario: Weekday token in next week
- **WHEN** today is Friday and the user captures "Plan sprint @mon"
- **THEN** the task is due next Monday at 23:59 local time

### Requirement: Unrecognized tokens stay in the title
The system MUST leave any text starting with `!` or `@` that is not a recognized token unchanged in the title.

#### Scenario: Unknown token kept
- **WHEN** the user captures "Email @maria about !urgent issue"
- **THEN** the task title is "Email @maria about !urgent issue" with default priority and due date

### Requirement: Token feedback before saving
The system SHALL show the parsed priority and due date next to the capture field while the user types.

#### Scenario: Live preview
- **WHEN** the user has typed "Draft budget !high @fri" and has not pressed Enter
- **THEN** the capture field shows "High" and this Friday's date as the pending values
