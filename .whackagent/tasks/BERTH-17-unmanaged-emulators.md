---
issue: BERTH-17
phase: review
type: feature
wiki: [broker, architecture, android-backend]
note: Seen on 2026-11-18 after a daemon crash (BERTH-18): 4 berth emulators kept running untracked, berth showed 1/5 running.
created: 2026-11-18
---

## Context / Decisions

Ticket (user's words): "make berth detect un-managed running emulator just like connected device".

On 2026-11-18 the daemon crashed and the next daemon adopted none of its emulators (BERTH-18 fixes that). Four `qemu-system-aarch64-headless` processes kept running: `berth status` and berth-bar showed `1/5 running`, and nothing in berth told the user that 4 more emulators were up. Emulators started by hand, by Android Studio, or by the panel's "Launch emulator" for a non-pool AVD are invisible in the same way.

Grilled unattended by `/wa-autopilot` on 2026-11-18. Decisions tagged `(autopilot assumption)` are for the user to confirm or correct.

- An unmanaged emulator is an `emulator-*` entry of `adb devices -l` whose serial is not a broker slot, whatever the slot's state (`booting`, `preparing`, `stopping` included). Only the broker knows its slots, so the broker computes this list, not the backend. (autopilot assumption)
- It is shown exactly like a connected device (BERTH-13): one more row in the berth-bar "Devices" section, in the same `devices` list of the snapshot, with the same columns (serial, name, adb state) and the same mirror button (scrcpy in control mode, only in state `device`). Phones and unmanaged emulators share the section; the `emulator-` serial tells them apart. (autopilot assumption)
- The name column shows the AVD name (`adb -s <serial> emu avd name`, the call prepare already uses), because the `model:` field of an emulator is a generic image name (`sdk_gphone64_arm64`). The daemon asks once per serial and keeps the answer while the serial stays in the adb list, so a reap tick does not run one more adb call per emulator. When the call fails, the row falls back to the `model:` field, then `—`. (autopilot assumption)
- Unmanaged emulators are listed whatever the pool holds (Android, iOS-only or empty), like phones. (autopilot assumption)
- Seen, never managed: berth never adopts, leases, resets, stops or counts an unmanaged emulator (`maxRunning`, the summary line `n/m running`). It may be the device of an agent that still works on it, so handing it to a claim would collide. The daemon never stops it on its own. The user can kill it from its row (feedback round 1, below).
- `berth status` and `berth top` tables stay as they are, as for phones; `berth status --json` carries the rows in `devices`. (autopilot assumption)
- The snapshot type keeps its name `PhysicalDevice` and its wire key `devices`: no protocol change, an older berth-bar shows the new rows as devices. (autopilot assumption)

## Acceptance criteria

- An unmanaged emulator's row has a kill button. A click runs `adb -s <serial> emu kill` from berth-bar, and the row leaves within one reap tick once the emulator is gone. Its tooltip warns that an agent may still use the emulator. Phones and berth's own emulators get no kill button. (feedback round 1)
- With an emulator running that berth did not start (for example `emulator -avd <name> -no-window` from a terminal), the berth-bar "Devices" section lists it within one reap tick (about 5 s): its serial `emulator-<port>`, its AVD name and its adb state.
- Its mirror button opens a scrcpy window in control mode when its state is `device`; in another state the row has no button.
- An emulator that berth manages (any slot state, including `booting`, `preparing` and `stopping`) never appears in "Devices".
- When the unmanaged emulator stops, its row leaves within one reap tick, and "none connected" shows when no row is left.
- The rows are listed with an Android pool, an iOS-only pool and an empty pool.
- `berth claim` never grants an unmanaged emulator, the summary `n/m running` does not count it, and the daemon never stops it.
- A reap tick runs `adb -s <serial> emu avd name` at most once per unmanaged serial while that serial stays listed.
- `berth status` table output is unchanged; `berth status --json` lists the emulator in `devices`.
- Broker tests cover the cases above with the fake backend; the panel render test covers a device list holding a phone and an unmanaged emulator; `swift build` and `swift test` pass.

## Implementation

- `DeviceListing.emulators`: every `emulator-*` entry (serial, `model:`, adb state); `live` stays pool-gated. `DeviceRouter` merges `emulators` from the Android backend whatever the pool.
- `DeviceBackend.avdName(serial:)` (default nil; Android backend already had it, router forwards by serial shape): the broker asks the backend, no preparer needed.
- `Broker.publishedDevices`: phones, then unmanaged emulators (listing emulators minus every slot serial, any state) sorted by serial number; `model` = AVD name, else `model:` field, else nil. Name cached per serial in `avdNames` (failures cached too), dropped when the serial leaves the listing. Used by `restore()` (after adoption) and `reap()`.
- Autofix 1: preparing-slot test, router tests assert `live`, `avdNames` prune uses a serial set.
- No change to slots, grants, maxRunning, summary, stop, `PhysicalDevice`, `DeviceRow`, `MirrorController`.
- Tests: listing, router (Android / iOS-only / empty pool), broker (listed, ordering, nameless, never granted, managed in booting/leased/stopping never listed, leaves when gone, avdName once per serial), render fixture `live-devices` (+ dark) holds phones and two emulator rows.

- Round 1 (kill button): `EmulatorKiller` protocol + `AdbEmulatorKiller` (`adb -s <serial> emu kill` through `Shell.run`, bar's `Config.defaultADBPath()`), `KillEligibility` (button on every `emulator-*` device row, any adb state: an offline orphan is what one kills), `EmulatorLauncher.kill(serial:)` (failure shows in the existing `launcher.error` caption), `DeviceRow` kill button (tooltip warns an agent may use it; no dialog, no daemon call). The button column takes width from the state column so mirror buttons stay aligned.

## Review

### validation (autopilot) — 2026-11-18

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict after 2 rounds: clean.

Round 1, 3 findings (all 🟡), all fixed by autofix:
- [correctness] No test proved that an emulator in a `preparing` slot stays out of `devices`. Fixed: new case in `BrokerPrepareTests`.
- [style] The router test name said "live stays pool gated" but nothing asserted `live`. Fixed: both tests set a live serial and assert it.
- [elegance] The `avdNames` prune used a misleading closure name and a nested `contains`. Fixed: filter on a `Set` of serials.

Round 2: clean. Withdrawn: 0. Disputed: 0.

## Verification

- `swift build` green, 0 warnings; `swift test` green (63 + 146 + 76 + 79 tests).
- Own daemon (`BERTH_HOME=/tmp/b17`) with 5 running emulators: `berth status --json` `devices` lists the phone and emulator-5554..5562 named `Pixel_9`; `slots` empty; `berth status` table unchanged (no device rows). Daemon killed by pid; emulators untouched (5 still listed).
- Panel proof: render PNGs `live-devices.png` / `live-devices-dark.png`.

- Round 1: build green, 0 warnings; tests green (+ `KillEligibilityTests`, 2 launcher kill tests with `FakeEmulatorKiller`). Render PNGs `live-devices` / `live-devices-dark` show the kill button on both emulator rows only. The click itself was not run: it stays a manual check for a human, no real emulator touched.

## Feedback

### Round 1 — 2026-11-18

Asked: "Add button to kill emulator".
Triage: adjustment. It corrects the autopilot assumption "no stop button". Decisions (agent's, most reversible): the button is on unmanaged emulator rows only. berth-bar runs `adb -s <serial> emu kill` itself (no daemon or protocol change, like the plain "Launch emulator" for non-pool AVDs). No confirmation dialog: the tooltip warns that an agent may still use it.
Changed: new `EmulatorKiller` protocol + `AdbEmulatorKiller` (`adb -s <serial> emu kill`, 15 s timeout, bar's adb path) and `KillEligibility` (every `emulator-*` device row, whatever its adb state: an offline orphan is exactly what you would kill) in `Sources/BerthBar/Launch/`. `EmulatorLauncher.kill(serial:)`: a failure shows in the launcher's error caption. `DeviceRow` has a kill column (taken from the state column so the mirror column still lines up). Tests: `KillEligibilityTests`, `EmulatorLauncherTests` (+2), render fixture `live-devices` (light + dark).
Warnings: 0 new. Review: deferred to `/wa-validate`. Verify: unit + render tests green. The click itself stays a manual check (desktop proof rules: no click on berth-bar), and no real emulator was killed.
