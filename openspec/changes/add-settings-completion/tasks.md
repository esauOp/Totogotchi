## 1. Export and import

- [ ] 1.1 Add a transfer controller that exports through `NSSavePanel`, defaulting the filename to the current date, and verify the chosen location receives exactly one JSON file carrying tasks, weekly statistics and usage events
- [ ] 1.2 Report success with the file's name and failure with its reason in Settings, and verify both by exporting to a writable location and to one that is not
- [ ] 1.3 Treat cancelling the save panel as neither success nor failure, and verify nothing is written and nothing is reported
- [ ] 1.4 Add import through `NSOpenPanel` restricted to JSON, reporting how many tasks were read, and verify a round trip restores the tasks and the weekly counters
- [ ] 1.5 Verify an import merges: a task present in the file replaces the stored copy, and a task absent from the file is left alone
- [ ] 1.6 Report a readable reason when the chosen file is not an export or uses an unknown format version, and verify with a text file and with a file claiming format 99
- [ ] 1.7 Verify the app still holds no network sockets and no network entitlement after an export

## 2. Launch at login

- [ ] 2.1 Add a launch-at-login controller over `SMAppService.mainApp` that reads its state from `status` rather than from a preference, and verify the switch matches the system after being changed outside the app
- [ ] 2.2 Register and unregister on the switch, and verify the state survives closing and reopening Settings
- [ ] 2.3 Surface a refusal, including `.notFound` and `.requiresApproval`, and verify the message appears and the switch returns to off when macOS declines
- [x] 2.4 Install the Release build into `/Applications` so registration can be verified on a real copy, and record whether it succeeded in design.md

## 3. Settings

- [ ] 3.1 Add the two sections to Settings without disturbing the hotkey recorder or the notifications toggle, and verify all four areas still work
- [ ] 3.2 Give every new control a VoiceOver label and keyboard reachability, and verify by tabbing through Settings

## 4. Acceptance

- [ ] 4.1 Walk every scenario in both specs of this change as a manual QA pass against a scratch store, not the owner's tasks, and verify each passes; note any deviation in design.md
- [x] 4.2 Run `swift test` in `TotogotchiCore` and verify the whole suite passes
