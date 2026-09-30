# Auto Quit

## Invariants

- Off by default. Only apps explicitly added in **Settings → Auto Quit** are considered.
- Each app gets a background delay from 1 to 1440 minutes, initially 15. Activating an app resets
  its countdown, even if it returns to the background between timer checks.
- Only finished-launching, regular GUI apps qualify. Finder, Tinycast itself, helpers and agents
  never receive a quit request.
- Quitting uses `NSRunningApplication.terminate()`, never force termination. An app can prompt for
  unsaved documents or refuse to quit. One request is sent per background spell; a refused or cancelled
  quit is not repeatedly requested. Activating the app arms a fresh countdown.
- Sleep and switching away from the user session suspend quitting. Wake and returning to the session
  start fresh countdowns. Restarting Tinycast, enabling the feature or editing the rules does too.
- State is channel-local in UserDefaults. Neither enablement nor rules travel in settings backups:
  an import must not arm unattended quitting or expand the targets of an already-enabled feature.
- `settings.json` mirrors `autoQuit.applications`; it cannot enable Auto Quit. Invalid rules or
  duplicate bundle IDs reject the whole edit and leave the existing rules intact.

## Implementation

`AutoQuitEngine` is a pure state machine over process snapshots, rules and an injected elapsed
`Duration`. It tracks individual processes rather than bundle IDs, so multiple instances have their
own countdowns. `AutoQuitMonitor` supplies workspace snapshots, observes macOS 26 typed notifications,
checks deadlines every five seconds with a `SuspendingClock`, and requests normal quits. A failed
request reports through Tinycast's HUD. No Accessibility or Automation grant is needed.

`AutoQuitStore` owns the two UserDefaults keys, `autoQuitEnabled` and `autoQuitRules`.
`AutoQuitCoordinator` is the settings action surface. `AppCore` owns all three, starts the monitor
and follows configuration through its existing Observation sink, including edits from settings.json.
The settings hierarchy injects only the coordinator into the pane.

```json
{
  "autoQuit": {
    "applications": [
      { "bundleID": "com.apple.Safari", "minutes": 15 }
    ]
  }
}
```

## Maintaining the fork

All feature behavior, settings UI, persistence and file encoding stay in
`Tinycast/Features/AutoQuit/`. The shared integration points are:

- `AppCore`: ownership, startup, Observation, termination and settings-file wiring.
- Settings: sidebar/detail registration, environment injection, search anchors/catalog and file key/schema.
- `AppSettingsKey` and `SettingsBackupCoverage`: key registration and explicit backup exclusions.
- `Scripts/run-tests.sh`: the `auto-quit-test` harness.

There are no changes to launcher behavior, app indexing, permissions, extension code or design tokens.
When rebasing onto upstream, preserve these registrations and regenerate the Xcode project with
`xcodegen generate` if its source list changes. The feature requires no packages or generated runtime.

## Verification

`auto-quit-test` compiles the shipped model and store. It checks deadline boundaries, foreground resets,
brief activations, independent instances, excluded apps, cancelled-request suppression, restarts,
process removal/reuse, changed/removed rules, invalid persisted records and settings-file round trips.

Manual check: add a disposable app with no unsaved work, set one minute, enable Auto Quit and switch
away. It should receive a quit request after about 60–65 seconds. Returning before the deadline starts
another full minute when you leave again. Repeat with an unsaved document and cancel the app's quit
prompt; there should be no second request until you activate that app again. Also check disable,
remove, sleep/wake and user switching, and verify the pane in both appearances.
