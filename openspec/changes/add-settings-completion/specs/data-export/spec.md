## Purpose

Lets the user take their tasks, weekly statistics and usage history out of the
app in a format they own, and put them back, so the data is never trapped inside
one Mac's sandbox container.

## ADDED Requirements

### Requirement: Export to a location the user chooses
The system SHALL let the user export from Settings, MUST ask where the file goes, and MUST write exactly one file at the chosen location.

#### Scenario: Export succeeds
- **WHEN** the user chooses Export and picks a location
- **THEN** one JSON file is written there containing the tasks, the weekly statistics and the usage events, and Settings confirms it

#### Scenario: Export cancelled
- **WHEN** the user opens the save panel and cancels
- **THEN** nothing is written and nothing is reported as an error

#### Scenario: Export fails
- **WHEN** the file cannot be written
- **THEN** Settings says so, naming the reason

### Requirement: Import from a previously exported file
The system SHALL let the user import a file it exported, and MUST accept both format versions it has ever written.

#### Scenario: Import restores what was exported
- **WHEN** the user imports a file exported by this app
- **THEN** its tasks are present, its weekly counters are restored, and Settings reports how many tasks were read

#### Scenario: Import merges rather than replaces
- **WHEN** the imported file contains a task that already exists
- **THEN** the stored copy is replaced by the imported one and tasks absent from the file are left alone

#### Scenario: Import rejects a file it cannot read
- **WHEN** the chosen file is not a Totogotchi export, or uses a format newer than this app knows
- **THEN** nothing is changed and Settings explains why

### Requirement: Exporting never leaves the device
The system MUST write only to the location the user chose and MUST NOT transmit the data anywhere.

#### Scenario: No network use
- **WHEN** the user exports
- **THEN** the app makes no network connection, and it holds no entitlement that would allow one
