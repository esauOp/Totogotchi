## Context

Every change in the original plan is archived and the MVP works. This change
closes the two PRD promises that had no home in any of them: exporting data from
Settings, and launching at login. See proposal.md for how they were missed.

The archive code already exists and is tested. `TaskStore.exportArchive` writes
format 2 with tasks, weekly statistics and usage events; `importArchive` reads
both format 1 and 2. This change is almost entirely about reaching them.

## Goals / Non-Goals

**Goals:**
- Make the export the user was promised reachable in two clicks.
- Make the app present after a restart without being asked.
- Fail loudly in both cases, because a silent no-op on a backup feature is worse
  than an error.

**Non-Goals:**
- Scheduled or automatic backups.
- Any change to the archive format.
- Migrating anything: an import merges into the current store rather than
  replacing it.

## Decisions

### Decision: The standard save and open panels, not a path field
`NSSavePanel` and `NSOpenPanel` are how a sandboxed app gets access to a file
outside its container: choosing a file through them grants the app permission to
it. A text field where the user types a path would simply be denied. This is not
a UI preference, it is the only route that works under the sandbox.

### Decision: Import merges, it does not replace
`importArchive` upserts by identifier, so a task in the file replaces the stored
copy with the same identifier and tasks absent from the file are untouched.

Chosen over wiping the store first. Replacing is the more surprising of the two:
someone importing an old backup to recover one lost task should not lose
everything they have done since. Merging is also what makes the round trip in
the existing tests meaningful.

The trade-off is that a merge cannot undo a deletion made after the export. That
is worth the safety.

### Decision: The login-item switch reads `SMAppService.status`, never a preference
`SMAppService.mainApp.status` is the truth. A stored boolean would drift the
moment the user removed the app from login items in System Settings, and the
switch would then lie.

`register()` and `unregister()` both throw, and the status can come back as
`.requiresApproval` or `.notFound`. All three cases are surfaced. `.notFound` is
the one this project will actually hit: an app running from DerivedData with an
ad-hoc signature is not something macOS will register, which is why installing
into `/Applications` is a prerequisite for verifying this rather than an
afterthought.

### Decision: Results are reported in Settings, not in an alert
Both operations report into a line under their button. An export that worked
needs a quiet confirmation, not a modal to dismiss; an export that failed needs
its reason visible while the user tries again. Modal alerts are reserved for
things the app cannot continue past, which is how the storage-failure alert is
already used.

## Risks / Trade-offs

- [`SMAppService` will not register an ad-hoc signed build from DerivedData] →
  expected, and the spec requires the refusal be explained rather than hidden.
  Verifying the happy path needs the app installed in `/Applications`, which is
  the next operational step either way. Maps to PRD §9.1.
- [An import silently overwriting good data with stale data] → merge rather than
  replace, and the result line says how many tasks were read so a surprise is
  visible immediately.
- [The export carries the usage log, which is a record of behaviour] → it stays
  on the device, the file goes only where the user put it, and the log never held
  task titles in the first place.

## Open Questions

- Should the export default to a filename with the date in it? Assumed yes,
  `Totogotchi-YYYY-MM-DD.json`, because the first thing anyone does with a backup
  is make a second one. Does not change the specs.

## Implementation notes

### Task 2.4: installed into `/Applications`

The Release build is now at `/Applications/Totogotchi.app` and the running
process comes from there rather than from DerivedData. This was a prerequisite
rather than a nicety: `SMAppService` will not register an app it cannot find at a
stable path, and until now the only copy lived in a build folder that
`xcodebuild clean` would delete. It also unblocks PRD milestone M4, a week of
real use, which could not honestly start against a build artefact.

The copy is still ad-hoc signed with no team identifier. Whether `SMAppService`
accepts an ad-hoc signature is the open question that the manual pass answers;
if it refuses, `specs/launch-at-login` requires the refusal be explained, and the
message for `.notFound` says exactly this.
