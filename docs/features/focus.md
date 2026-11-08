# Focus

Timed focus sessions that quit distracting apps, modelled on Raycast Focus. Apps only for now:
website blocking needs per-browser tab reading and Automation grants, and is planned separately.

## Invariants

- Nothing is blocked outside a session, and a session only starts from an explicit command, the
  floating bar or a consented deeplink. There is no enable switch to arm it unattended.
- Quitting uses `NSRunningApplication.terminate()`, never force termination, so an app may ask to
  save or refuse. A refused app is asked again only after the user leaves it and brings it back.
- Finder, System Settings, Activity Monitor, the login window and Tinycast itself are never quit,
  in either mode. Listing them does nothing: an allow list must not be able to lock the user out.
- Time counts only while a session runs. A break or sleep stops the clock, and so does quitting
  Tinycast: `prepareForTermination` suspends the session and the next launch restarts its clock.
- A session persists across restarts in UserDefaults. Neither it nor the remembered block list
  travels in a backup or settings.json, so an import cannot widen what a session quits.
  `focus.reopensQuitApps` is deliberately not mirrored either: it launches apps unattended.
- The bar, menu item and glow belong to `FocusCoordinator`; nothing outside the feature reaches them.

## Behaviour

**Start Focus Session** opens the palette with the search field as the goal. Rows choose a
duration (presets, **No Limit** or a typed custom length such as `1h 30m`), the mode and the list;
⌘↵ starts from any row. **Choose Apps & Categories…** lists the built-in categories, then the
listed apps, then every other app. Each start remembers its setup for the next one and for
**Toggle Focus Session**, which starts with it or completes the running session.

- **Block** quits the listed apps and categories. **Allow** quits everything else.
- Starting, resuming and editing sweep running apps. Opening a blocked app later quits it with an
  orange edge glow and a HUD, and offers **Snooze** for the configured length (1–10 min, or none).
  A snooze reopens the app; when it ends, the app is quit the next time it comes forward.
- **Pause Focus Session** offers 5, 10, 15 or 30 minute breaks, or **Pause Until I Resume**. A
  timed break resumes by itself.
- A timed session that reaches zero asks to extend by 5 or 15 minutes or wrap up; wrapping up
  flashes green. **Reopen quit apps when a session ends** relaunches what the session quit, in the
  background.
- The session shows in a floating bar (goal, countdown, ring, pause, complete, edit, move) or as a
  menu bar countdown whose menu holds the same actions. Settings › Focus picks which.

`tinycast://command/start-focus-session?arguments={…}` starts a session from a link after consent.
Fields: `goal`, `duration` (minutes, `1h30`, or `none`), `mode` (`block`/`allow`), `categories`
(comma-separated IDs: `social`, `work-chat`, `email`, `entertainment`, `news`, `gaming`) and `apps`
(comma-separated bundle IDs). Unset fields keep the remembered setup; an unknown field or value
rejects the link. The other commands link as `command/<name>` with no input.

## Implementation

`FocusSession` and `FocusConfiguration` are pure values over an injected `now`; they decide what is
blocked, the clock, breaks, sleep, snoozes and link fields. `FocusStore` persists them and the four
preferences. `FocusMonitor` observes typed workspace notifications, quits what the coordinator's
verdict blocks, and ticks once a second only while a session exists. `FocusCoordinator` owns the
session actions, the palette screens' draft, `FocusBarController`, `FocusMenuBarController` and
`FocusGlowController`. `AppCore` owns the store, monitor and coordinator, restores in `start()`,
suspends in `prepareForTermination()`, and re-presents when `barPlacement` changes.

Category bundle IDs are curated starting points; one that is not installed never matches.

## Verification

`focus-test` compiles the model and store. It covers duration parsing, normalisation, block and
allow verdicts, protected apps, the clock, pause, breaks, sleep, snoozes, extension, editing, link
fields, persistence and repair, and the clock text.

Manual check, with a disposable app that has no unsaved work:

1. Start a 1-minute session blocking that app. It should quit, and reopening it should quit it again
   with an orange glow and a HUD.
2. Snooze it from the bar: it reopens and stays open for the snooze length.
3. Pause for 5 minutes, open the app (it stays), resume, and confirm it quits.
4. Let the minute run out: extend once, then wrap up and see the green glow.
5. Move the bar to the menu bar and back, in both appearances and over a light desktop.
6. Quit Tinycast mid-session and relaunch: the session and its remaining time return.
