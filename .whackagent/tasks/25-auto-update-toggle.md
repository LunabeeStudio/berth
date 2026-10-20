---
issue: 25
phase: validated
type: feature
wiki: [[update]], [[architecture]]
note: User request (2026-10-20): add auto-update entry next to launch at login in tray. Grilled unattended by autopilot.
created: 2026-10-20
---

## Context / Decisions

User request (2026-10-20): "add auto-update entry next to launch at login in tray". The tray is the `berth-bar` panel. Auto update exists today only as the `autoUpdate` key in `config.json` (default true, also when the key is absent). The daemon reads that key once when it starts (`Daemon.swift` builds `AutoUpdater` with `config.autoUpdate`), so changing it today needs `berth daemon stop`.

Decisions:
- **Control.** A checkbox "Auto update" in the same row as "Launch at login", to its right, same style (`.toggleStyle(.checkbox)`). (autopilot assumption: "next to" read as same row.)
- **What it changes.** The checkbox shows and writes the `autoUpdate` key of the berth config file (`Paths.config`), the same key `berth update` users and the daemon already use. No new key, no protocol verb, no daemon call. Writing keeps every other key of the file and uses the daemon's format (pretty printed, sorted keys, atomic write).
- **No config file, or an unreadable one.** The checkbox is disabled and shows the default (checked). `berth-bar` never creates the config file: the daemon creates it on first run with pool discovery, and a file written by the bar would hold an empty pool. (autopilot assumption)
- **Taking effect without restart.** The daemon reads `autoUpdate` from the config file again before each check: about 60 s after it starts, then every 24 h. Turned off → the next check does nothing. Turned on → the next scheduled check installs a newer release. A daemon started with it off keeps its check loop running, so turning it on later works without a restart. A `dev` daemon never updates, whatever the checkbox says.
- **Fresh state.** The checkbox re-reads the file when the panel opens, like "Launch at login", so a hand edit of `config.json` shows.
- **A write that fails** (file not writable) leaves the file as it was, and the checkbox shows what the file holds after the attempt. (autopilot assumption: no extra caption, YAGNI.)
- **Where it lives.** `berth-bar`: a new feature folder `Sources/BerthBar/Update/` with an `@Observable @MainActor` setting model like `Login/LaunchAtLogin`, its config URL injectable for tests, created in `App/BerthBarDelegate.swift` and handed to `StatusPanel` like `LaunchAtLogin`. Daemon: `AutoUpdater` takes a closure that says whether auto update is on, called before each check; `Daemon.swift` passes one that reads `Config.load()` (missing file → true, the key's default). BerthCore: reuse `Config.load(from:)`; add a write helper only if the bar and `loadOrCreate` can share it.
- **Docs.** README "Menu bar" (the checkbox) and "Updates" (checkbox or key, no daemon restart needed for it). Wiki `update` and `architecture`.

## Acceptance criteria

- `swift build` and `swift test` pass.
- The `berth-bar` panel shows an "Auto update" checkbox in the same row as "Launch at login", to its right, in every panel state (connecting, live, daemon not running).
- The checkbox is checked when the config file has `"autoUpdate": true` or no `autoUpdate` key, and unchecked when it has `"autoUpdate": false`.
- Toggling the checkbox writes `autoUpdate` true or false to the config file and leaves every other key and value of the file unchanged.
- When the config file does not exist or cannot be decoded, the checkbox is disabled, shows checked, and `berth-bar` writes nothing.
- Opening the panel after `config.json` was edited by hand shows the value from the file.
- With `autoUpdate` false in the file, a running daemon's next check installs nothing, without a daemon restart.
- A daemon started with `autoUpdate` false installs a newer release at its next scheduled check after `autoUpdate` is set to true, without a restart.
- A `dev` daemon never checks for updates, whatever `autoUpdate` says.
- README documents the checkbox and that it takes effect without a daemon restart.

## Implementation

Autopilot run, 2026-10-20. One implementer, 2 bricks, then 3 autofix rounds.

- Brick 1 (daemon):
  - `AutoUpdater` takes `isAutoUpdateEnabled: @Sendable () -> Bool`, called before each check.
  - On a dev build, `run()` returns at once and nothing is checked.
  - A release daemon keeps its loop running while the setting is off.
  - `SelfUpdate/AutoUpdateFlag` (new) reads `autoUpdate` from `config.json`. It keeps the last good value (seeded from the startup config) when the file is missing or unreadable, and logs an unreadable file.
  - `Daemon.swift` passes `AutoUpdateFlag.isEnabled`.
- Brick 2 (berth-bar):
  - `Update/AutoUpdateSetting` (new): `@Observable @MainActor`, with `isEnabled`, a tracked `isAvailable` and `refresh()`.
  - `StatusPanel`: an `HStack` with "Launch at login" and "Auto update" (checkboxes), disabled when the config is unavailable, shown in every state.
  - `StatusItemController` refreshes it when the popover opens. `BerthBarDelegate` creates it.
- BerthCore `Config`:
  - `save(to:)` (pretty, sorted, atomic), which `loadOrCreate` reuses.
  - `setAutoUpdate(_:at:)`: decodes the file as `Config` first, then edits the raw JSON key `autoUpdate` only, keeping unknown and absent keys, with an atomic write. It never creates the file.
- Tests:
  - `AutoUpdaterTests`: turned on → a newer release is installed, turned off → checks stop, dev never checks.
  - `AutoUpdateFlagTests`.
  - `AutoUpdateSettingTests`: raw JSON compared before and after, plus the unavailable cases.
  - `ConfigTests`: `save`, and `setAutoUpdate` with undecodable, missing and unknown-key files.
  - Render tests with the checkbox on, off and disabled, in light and dark.
  - Shared `LockedLines` helper.
- README: the Menu bar sentence, the Updates paragraph (checkbox or key, no restart), and `berth daemon stop` marked "except `autoUpdate`".
- Wiki: `update` and `architecture`.

## Review

Round `validation (autopilot)`. LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓.

- Pass 1: 1 major, 10 minor. The major one: the toggle re-encoded `Config` and dropped unknown keys; it was replaced by a raw JSON edit. The minor ones:
  - a malformed config forced `true`
  - `?? nil` noise
  - `isAvailable` was not tracked
  - the "turned on" test did not check an install
  - the "keeps other keys" test was partial
  - README rows for `berth daemon stop` and the unreadable file
  - the wiki
  - force unwraps
  - leftover temp files
- Pass 2: 7 minor:
  - `setAutoUpdate` wrote undecodable files
  - wrong error type
  - hard-coded key string
  - no Core tests for `setAutoUpdate`
  - the daemon closure was untestable, moved to `AutoUpdateFlag`
  - member order
  - stale wiki lines
- Pass 3: 2 minor test cleanups (a duplicate log helper and the helper's placement).
- Pass 4: clean. All findings were fixed; none were accepted.

## Verification

- `swift build` ✅. Full `swift test` ✅: 37, 83, 36 and 57 tests, all passed. It needs `DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer`.
- Daemon logic by unit tests:
  - setting off → no check
  - off → on with the same daemon → a newer release is installed
  - on → off → checks stop
  - dev build → never checks
  - unreadable or missing config → last good value
- Bar by unit tests:
  - a missing key reads checked
  - a toggle changes only `autoUpdate` in the raw JSON
  - missing or undecodable file → disabled, nothing written
  - `refresh()` picks up a hand edit
- Render PNGs checked: Auto update to the right of Launch at login, checked, unchecked and disabled, light and dark.
- Runtime check per `CLAUDE.md#Desktop proofs`, re-run on the final code. Own `.build/debug/berth-bar` launched with `BERTH_HOME=/tmp/bb25` and a hand-written config, then stopped by pid. The frontmost app was unchanged (Google Chrome), and the config file was byte-identical afterwards, so the bar does not write on launch.
- Not run by agent: clicking the checkbox, which needs the popover open (human check), and a real daemon picking up the change at its 24 h check (proven by unit tests with short intervals).

## Feedback
