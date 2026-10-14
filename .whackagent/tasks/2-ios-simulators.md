---
issue: 2
phase:
wiki: [[architecture]], [[broker]], [[cli]], [[ios-backend]] (new)
note:
created: 2026-10-14
---

## Context / Decisions

Request: "Handle iOS simulators". berth leases iOS simulators to parallel agents the same way it leases Android emulators. The README and the architecture wiki already planned it: an iOS backend implements `DeviceBackend` with `xcrun simctl`, and the broker stays platform-agnostic.

Prior art: `xcrun simctl` (create / boot / bootstatus / shutdown / erase / list -j) covers the whole lifecycle; no library needed. Tools such as fbsimctl/idb wrap the same calls and would add a dependency for nothing.

Decisions (all taken unattended by autopilot; each one is tagged and listed in the report for the user to confirm or correct):

- **One daemon, both platforms.** iOS simulators live in the same pool, queue and `maxRunning` limit as Android emulators (they compete for the same RAM, so eviction across platforms is allowed). (autopilot assumption)
- **Config.** A pool entry is either `{"avd": "Pixel_9", "maxInstances": 2}` (Android, unchanged) or `{"simulator": "iPhone 17", "maxInstances": 2}` (iOS). The `simulator` value is a simctl device type name or identifier; the runtime is simctl's default (newest compatible). Existing config files decode unchanged. No `runtime` key for now (YAGNI). iOS entries are never added automatically on first run: the user opts in by editing the config. (autopilot assumption)
- **berth owns dedicated devices, never the user's.** For each iOS pool entry the daemon makes sure `maxInstances` devices named `berth-<simulator>-<k>` exist (`simctl create`), creating missing ones at daemon start. Only devices whose name starts with `berth-` are ever booted, erased or shut down by berth. Devices are kept between leases and between daemon runs (no clone churn). (autopilot assumption)
- **Serial = device UDID.** That is what `xcodebuild -destination "id=…"` and `xcrun simctl … <udid>` take. (autopilot assumption)
- **Clean state = erase.** Launch = `simctl erase` then boot; reset = shutdown + launch + wait ready, like Android's reset-by-restart. Every lease starts from a factory-clean device. A user-prepared template state is not supported (it would need re-cloning, which changes the UDID). (autopilot assumption)
- **Ready** = `simctl bootstatus <udid>` returns, bounded by `bootTimeoutSeconds`. Headless: `simctl boot` never opens Simulator.app. No PID is tracked for a simulator.
- **Live devices** (reap / adopt on restart) = booted devices named `berth-…`. If one platform's query fails, the combined answer is "unknown" (nil) so a transient adb or simctl failure never stops slots of either platform.
- **Routing.** A small router `DeviceBackend` dispatches each call to the Android or the iOS backend (by model for boot, by serial shape for the rest: `emulator-<port>` = Android). The broker learns only that a claim may be restricted to a platform.
- **Claim / CLI.** `berth claim` and `berth run` with no device option keep claiming an Android emulator (existing agents and docs/AGENTS.md unchanged). `--ios` claims any iOS simulator of the pool; `--simulator "<name>"` claims that pool entry (implies `--ios`). `--avd` together with `--ios`/`--simulator` is a usage error. Old clients that send no platform are treated as Android. (autopilot assumption)
- **Run env.** `berth run` sets `SIMULATOR_UDID=<udid>` for an iOS lease (and not `ANDROID_SERIAL`). (autopilot assumption)
- **Status / top** show iOS slots next to Android ones; the model column shows the simulator name. Long UDIDs may be truncated in the table; `status --json` and `claim` output carry the full UDID. `release` / `renew` accept the full UDID or the lease id.
- **Out of scope:** `berth prepare` stays Android-only (erase replaces it for iOS). Physical iOS devices, watchOS/tvOS/visionOS, a per-entry runtime, deleting berth devices on `stop-all`.
- **Layout.** Backends move into `Sources/BerthDaemon/Backends/` (`DeviceBackend`, `AndroidBackend`, new iOS simulator backend, router); tests mirror it. `Platform` enum lives in `BerthCore`.
- **Docs.** README (config, commands, how it behaves) and `docs/AGENTS.md` get an iOS section; wiki gets an `ios-backend` page.

## Acceptance criteria

- A config with `{"simulator": "iPhone 17", "maxInstances": 2}` in `pool` loads; a config with only `avd` entries (today's format) loads unchanged and behaves as before.
- At daemon start, berth creates the missing `berth-iPhone 17-<k>` devices (up to `maxInstances`) and leaves every other simulator on the machine untouched, including one already booted by the user.
- `berth claim --ios --json` prints a grant whose serial is the UDID of a booted `berth-…` simulator; `xcrun simctl list devices` shows it `Booted`.
- `berth claim` with no device option never grants an iOS simulator, and `berth claim --ios` never grants an Android emulator.
- `berth run --ios -- sh -c 'echo $SIMULATOR_UDID'` prints the leased UDID, exits with the command's status, and releases the lease.
- After `berth release <udid>`, the device is erased and booted again: a file written into the simulator during the lease (e.g. via `simctl addmedia` or an installed app) is gone, and the slot returns to `free`.
- `berth status` lists the iOS slot with its simulator name, state and lease; `berth status --json` carries the full UDID.
- `berth claim --simulator "Unknown device"` for an entry not in the pool fails with the same "not in the pool" error as an unknown AVD; `--avd X --ios` is rejected as a usage error.
- `berth stop-all` and idle shutdown shut down berth's simulators and never shut down a simulator berth did not create.
- `swift build` and `swift test` pass; new unit tests cover config decoding of both entry kinds, platform filtering in the broker, and parsing of `simctl list devices -j` output.

## Implementation

## Review

## Verification

## Feedback
