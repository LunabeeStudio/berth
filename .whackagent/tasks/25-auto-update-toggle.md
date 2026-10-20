---
issue: 25
phase:
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

## Review

## Verification

## Feedback
