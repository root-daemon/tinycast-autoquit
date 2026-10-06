# Auto Quit

## Invariants

- Off by default. Only apps explicitly added in Settings or the launcher’s **Auto Quit** command are considered.
- Each app gets a background delay from 1 to 1440 minutes, initially 15. Settings and the panel
  offer 5, 10, 15, 30, 45 and 60 minutes plus a custom value. Activating an app resets
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
- `settings.json` mirrors `autoQuit.applications` and the command’s shortcut, alias and visibility
  through `autoQuit.commands`; it cannot enable Auto Quit. Invalid rules or
  duplicate bundle IDs reject the whole edit and leave the existing rules intact.

## Implementation

`AutoQuitEngine` is a pure state machine over process snapshots, rules and an injected elapsed
`Duration`. It tracks individual processes rather than bundle IDs, so multiple instances have their
own countdowns. `AutoQuitMonitor` supplies workspace snapshots, observes macOS 26 typed notifications,
checks deadlines every five seconds with a `SuspendingClock`, and requests normal quits. A failed
request reports through Tinycast's HUD. No Accessibility or Automation grant is needed.

`AutoQuitStore` owns the two UserDefaults keys, `autoQuitEnabled` and `autoQuitRules`.
`AutoQuitCoordinator` is the action surface shared by Settings and the palette. `AppCore` owns all three, starts the monitor
and follows configuration through its existing Observation sink, including edits from settings.json.
Both view hierarchies inject the coordinator. Saving a panel edit returns to the app list and keeps
the edited application selected. Configuration can be edited while Auto Quit is paused; choosing a
delay never enables the feature.

```json
{
  "autoQuit": {
    "applications": [
      { "bundleID": "com.apple.Safari", "minutes": 15 }
    ]
  }
}
```

## Launcher panel

Search for **Auto Quit** in the launcher and press Return. The first row enables or pauses the feature;
configured apps appear before apps you can add. Search for an app, press Return, and choose a preset,
**Custom delay…**, or **Don't auto quit this app**. The custom row reveals a Minutes field beside the
search field; Tab focuses it and Return saves a valid integer from 1 to 1440. Escape goes back.

The Actions menu also offers the six presets, a custom edit, removal and the global pause switch.
Settings includes the same preset picker, a custom numeric field, **Manage in Launcher**, and the
command’s shortcut and visibility controls. The command remains available while the feature is paused.

## Installing the fork

Release builds use `Tinycast.app` and `com.tinycast.app`, replacing standard Tinycast in Applications
and retaining its preferences and Application Support data. Quit standard Tinycast before replacing
it. Debug builds remain isolated. The earlier `Tinycast AutoQuit` test builds used a separate bundle
ID, so their Auto Quit rules must be recreated in the replacement. The updater reads only this fork’s
GitHub Releases and keeps a repository-specific cache. Local ad-hoc builds may need permissions
granted again because the signature differs from the installed app.

## Maintaining the fork

All feature behavior, settings and palette UI, persistence and file encoding stay in
`Tinycast/Features/AutoQuit/`. The shared integration points are:

- `AppCore`: ownership, startup, Observation, termination and settings-file wiring.
- Settings: sidebar/detail registration, environment injection, search anchors/catalog and file key/schema.
- Launcher and palette: command registration/dispatch, two palette modes and screen/environment registration.
- `AppSettingsKey` and `SettingsBackupCoverage`: key registration and explicit backup exclusions.
- `Scripts/run-tests.sh`: the `auto-quit-test` harness.
- Updates: `ReleaseFeed.repository` points to the fork; the check cache is repository-specific.

The app index, permissions, extension code and design tokens are unchanged.
When rebasing onto upstream, preserve these registrations and regenerate the Xcode project with
`xcodegen generate` if its source list changes. The feature requires no packages or generated runtime.

## Verification

`auto-quit-test` compiles the shipped model and store. It checks deadline boundaries, foreground resets,
brief activations, independent instances, excluded apps, cancelled-request suppression, restarts,
process removal/reuse, changed/removed rules, invalid persisted records, settings-file round trips and
custom delay validation.

Manual check: add a disposable app with no unsaved work, set one minute, enable Auto Quit and switch
away. It should receive a quit request after about 60–65 seconds. Returning before the deadline starts
another full minute when you leave again. Repeat with an unsaved document and cancel the app's quit
prompt; there should be no second request until you activate that app again. Also check disable,
remove, sleep/wake and user switching, and verify the pane in both appearances.

Panel check: choose each preset and a custom delay, verify Settings reflects it, pause/resume, remove
an app, and check keyboard arrows, Tab, Return and Escape. Adding or removing an app must keep the
selection on that app after the list reorders. Invalid custom values must never be saved.
