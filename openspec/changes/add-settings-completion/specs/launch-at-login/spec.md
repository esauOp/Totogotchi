## Purpose

Keeps the app present without being asked. A widget that has to be launched by
hand after every restart is not always visible, which is the whole premise.

## ADDED Requirements

### Requirement: Launch at login can be turned on and off
The system SHALL offer a launch-at-login switch in Settings and MUST register or unregister the app with macOS when it changes.

#### Scenario: Turning it on
- **WHEN** the user turns the switch on
- **THEN** the app is registered as a login item and the switch stays on after Settings is closed and reopened

#### Scenario: Turning it off
- **WHEN** the user turns the switch off
- **THEN** the app is no longer registered and does not start at the next login

### Requirement: The switch reflects the real system state
The system MUST read its state from macOS rather than from a stored preference, so a change made in System Settings is shown correctly.

#### Scenario: Disabled outside the app
- **WHEN** the user removes Totogotchi from login items in System Settings and then opens Totogotchi's Settings
- **THEN** the switch shows off

### Requirement: Refusal is explained
The system MUST tell the user when macOS will not register the app, rather than leaving a switch that silently flips back.

#### Scenario: Registration refused
- **WHEN** macOS refuses to register the app, for example because it is running from a build directory rather than an installed copy
- **THEN** Settings shows why and the switch returns to off

#### Scenario: Approval required
- **WHEN** macOS reports that the login item needs the user's approval
- **THEN** Settings says so and points at System Settings
