## Why

Two things the PRD promises were never built, because they fell between the four
changes the work was sliced into. Neither appears in any spec, so no task asked
for them and no acceptance pass missed them.

PRD §5.3 and §6.2 both say the user can export their data to JSON from Settings.
`TaskStore.exportArchive` and `importArchive` exist, are tested, and already
write format 2 with the weekly statistics and the usage log. Nothing in the app
calls either. The feature is finished and unreachable.

PRD §6.2 also lists launch at login in the Settings sheet. It is not
implemented. For a menu-bar app whose entire value is being present, that means
no widget, no reminders and no pet after a restart until the user opens it by
hand. Milestone M4 is a week of real use, and it cannot honestly start that way.

## What Changes

- Add Export and Import to Settings, backed by the existing archive code, using
  the standard save and open panels so the sandbox grants access to whatever the
  user picks.
- Add a launch-at-login toggle backed by `SMAppService`, reflecting the real
  system state rather than a remembered preference.
- Report failure in both cases rather than silently doing nothing.

Non-goals:
- Automatic or scheduled backups. PRD §7.3 leaves backup to Time Machine and a
  manual export.
- Any change to the archive format. Version 2 already carries everything.
- iCloud sync, which PRD §4.2 keeps a Could for v2.

## Capabilities

### New Capabilities
- `data-export`: taking the user's data out of the app and putting it back, in a
  format they own.
- `launch-at-login`: the app being present after the Mac restarts.

### Modified Capabilities
<!-- none: nothing already specified changes behaviour -->

## Impact

- Settings gains two sections; no existing behaviour moves.
- `SMAppService` needs the app to live somewhere stable and be signed. Running
  from a DerivedData build with an ad-hoc signature may not register, which is a
  real constraint on verification rather than a bug in the code.
- Closes the last two PRD promises that had no home in a change.
