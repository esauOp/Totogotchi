## ADDED Requirements

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
