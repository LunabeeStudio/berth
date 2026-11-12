---
issue: BERTH-16
phase:
type: feature
wiki: [android-backend, architecture, broker, cli]
note:
created: 2026-11-12
---

## Context / Decisions

Ticket idea (pasted 2026-11-12): "Improve the setup: add the prepare feature to berth-bar, so we prepare an AVD for berth from the berth-bar UI." Added during the grill: the "Launch emulator" dropdown also offers AVDs that berth has not prepared.

### Prepare runs in the daemon

- Prepare becomes a daemon request, `Request.prepare(PrepareRequest{avd, settle})`. berth-bar links BerthCore only and `AndroidBackend` lives in BerthDaemon. The daemon owns the emulator lifecycle and the broker, so it can keep claims off the AVD while it prepares. Today the CLI has a race there: an agent claim can boot the same AVD mid-prepare.
- The boot sequence moves from `Sources/berth/Commands/Prepare.swift` to BerthDaemon `Prepare/AVDPreparer.swift`, unchanged: cold boot headless with `-no-snapshot-load -no-snapshot-save`, animations off, wake + dismiss keyguard, settle N seconds, `emu avd snapshot save <snapshotName>`, shutdown. The log stays at `<logs>/prepare-<avd>.log`.
- The daemon streams progress as `Event.progress(String)` lines (cold booting, settling, saved snapshot), then `ok` or `failure`.
- The connection is the request's lifetime, as with claims: a disconnect (Ctrl-C, bar Quit) cancels the prepare, the daemon shuts the emulator down, and the pool is left unchanged.
- `berth prepare <avd>` becomes a thin client of that request. It auto-spawns the daemon like `berth claim`, prints each progress event to stderr, and keeps `--settle` (default 20). iOS entries and unknown AVDs are still refused.

### Prepare in progress = a slot in state `preparing`

- A new `SlotState.preparing`, so the panel row, `berth status` and `berth top` show the prepare (serial, model, timer) with no extra UI.
- `SlotState` decoding gets a fallback for unknown values, so a client older than its daemon still decodes the snapshot.
- Claims for the AVD being prepared wait in the queue until the prepare ends. The broker never boots a second instance of that AVD meanwhile (two emulators on one AVD fail on the AVD lock).
- A prepare starts regardless of `maxRunning` (user decision: one emulator over the limit for about 30 seconds is fine). While it runs, its slot counts like any other, so new boots for claims respect the limit.

### Busy AVD

- The daemon stops the AVD's `free` instances itself, then prepares. Nothing is lost, and the bar has no stop button.
- It refuses when an instance is `leased`, `booting`, `resetting` or `stopping`, with the reason (for example `<avd> is in use: <serial> leased by <owner>`).
- It refuses when the AVD runs outside berth (a plain launch from the bar, Android Studio), checked with `adb emu avd name` on every live emulator, as the CLI does now.

### Pool membership

- Prepare is the only way an AVD joins the pool. On success, an AVD not yet in the pool is appended to `config.json` with `maxInstances: 2` (the first-run discovery default). A failed or cancelled prepare changes nothing.
- The append is a raw JSON edit, like `Config.setAutoUpdate`, so the other keys of the user's file stay as they are.
- The broker's pool becomes mutable and picks up the new entry live, with no daemon restart. The other config settings stay fixed at start.
- This replaces the CLI's note "not in the pool; add it to config.json".

### AVD list in the bar

- The bar reads the AVDs on disk and their prepared flag itself, each time the panel opens. No protocol field, and no `emulator -list-avds` in the 5-second reap loop.
- `listAVDs`, `avdDirectory` and the snapshot check (`hasCleanSnapshot`) move from `AndroidBackend` to BerthCore `Android/AVDCatalog.swift`. They only read the SDK and the AVD home. The daemon and the CLI call them from there.

### Menus in the bar (Android only, shown while the daemon is live)

- "Launch emulator" lists every Android AVD on disk.
  - Pool AVD: a windowed claim, as today (#19: label `you`, owner berth-bar, Release button on its row). A pool AVD without the snapshot still cold boots, as the daemon does today.
  - AVD outside the pool: a helper launch, independent of berth. The bar runs `Spawn.detached` on the SDK `emulator -avd <name>` with the emulator's own defaults (window, quickboot), logging to `<logs>/emulator-<avd>.log`. It outlives a bar Quit. berth does not track it. If that AVD already runs, the emulator refuses on its own lock and the error is only in the log.
  - An unprepared AVD is marked `(not prepared)` in this menu.
- "Prepare AVD", a separate menu, lists every Android AVD on disk that is not both in the pool and prepared. This covers unprepared AVDs and AVDs prepared earlier by the CLI but outside the pool. Prepared pool AVDs are left out: `berth prepare` still re-prepares them.
- Picking an AVD in "Prepare AVD" sends the prepare request. Progress shows as the `preparing` row. A failure shows in the error caption that the launcher already uses for claims.

### Where the code lives

- BerthCore: `Android/AVDCatalog.swift` (new). `Protocol.swift`: `Request.prepare`, `PrepareRequest`, `Event.progress`. `Model.swift`: `SlotState.preparing` + unknown-value fallback. `Config`: pool entry append by raw JSON edit.
- BerthDaemon: `Prepare/AVDPreparer.swift` (new). `Broker`: `prepare` entry (preparing slot, stop free instances, refusals, pool append on success, live pool). `Server`: routes `.prepare`.
- berth: `Commands/Prepare.swift` becomes a thin client.
- BerthBar `Launch/`: `DaemonActions.prepare`, `EmulatorLauncher.prepare(avd:)` (reuses its error caption), `PlainEmulatorLauncher` (protocol injected, `Spawn.detached` default), `AVDList` (refreshed on panel open).
- BerthBar `Panel/AVDMenus.swift` (new): the Launch and Prepare menus, moved out of `StatusPanel`.
- Not split: the bar parts are small once the daemon request and `AVDCatalog` exist (user decision).

## Acceptance criteria

- With an Android AVD on disk that has no `berth-clean` snapshot and is not in the pool, the panel's "Prepare AVD" menu lists it, and its "Launch emulator" menu lists it with `(not prepared)`.
- Picking it in "Prepare AVD" shows a row in state `preparing` for that AVD in the panel, and `berth status` shows the same slot while it runs.
- When that prepare succeeds, the row disappears, the AVD's directory holds `snapshots/berth-clean`, `config.json` has a new pool entry `{avd: <name>, maxInstances: 2}` with its other keys unchanged, and a `berth claim --avd <name>` is granted without restarting the daemon.
- After that, the next time the panel opens, "Prepare AVD" no longer lists the AVD and "Launch emulator" lists it without `(not prepared)`.
- A `berth claim --avd <avd>` sent while that AVD is preparing waits in the queue and is granted after the prepare ends. No second emulator of that AVD starts meanwhile.
- `berth prepare <avd>` on an AVD with one `free` berth instance stops that instance, prepares, and prints the progress lines on stderr, ending with the saved snapshot line. Exit code 0.
- `berth prepare <avd>` on an AVD with a `leased` instance fails at once with a message naming the serial and the owner, and leaves the instance running. Exit code non-zero.
- `berth prepare <avd>` on an AVD running outside berth fails at once with a message naming the serial.
- Pressing Ctrl-C during `berth prepare <avd>` shuts that emulator down, removes the `preparing` slot, and leaves `config.json` unchanged.
- A prepare that fails (for example a snapshot save error) shows its message in the bar's error caption, and the AVD does not join the pool.
- Picking an AVD outside the pool in "Launch emulator" opens a windowed emulator for it. berth does not list it as a slot, and it keeps running after the bar quits.
- Picking a pool AVD in "Launch emulator" still makes a windowed claim: the row shows label `you` and a Release button.
- `berth prepare` on an iOS pool entry or an unknown AVD name is still refused with the same messages as today.
- The panel render tests cover the two menus and a `preparing` row (`BERTH_PANEL_PNG_DIR=<dir> swift test --filter StatusPanelRender`).
