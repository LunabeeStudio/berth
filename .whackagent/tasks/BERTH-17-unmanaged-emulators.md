---
issue: BERTH-17
phase:
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
- Seen, never managed: berth never adopts, leases, resets, stops or counts an unmanaged emulator (`maxRunning`, the summary line `n/m running`). It may be the device of an agent that still works on it, so handing it to a claim would collide. No stop button: berth never stops an emulator it does not manage. (autopilot assumption)
- `berth status` and `berth top` tables stay as they are, as for phones; `berth status --json` carries the rows in `devices`. (autopilot assumption)
- The snapshot type keeps its name `PhysicalDevice` and its wire key `devices`: no protocol change, an older berth-bar shows the new rows as devices. (autopilot assumption)

## Acceptance criteria

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

## Review

## Verification

## Feedback
