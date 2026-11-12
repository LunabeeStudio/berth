---
issue: BERTH-13
phase: validated
type: feature
wiki: [broker, architecture]
note:
created: 2026-11-12
---

## Context / Decisions

Ticket:
- Show physical connected devices below the emulators.
- Allow to launch `scrcpy` (read write).
- It's just to see it, do not integrate it with the claim/release system.

Grilled unattended by `/wa-autopilot` on 2026-11-12. Decisions tagged `(autopilot assumption)` are for the user to confirm or correct.

- Surface: the berth-bar panel only, in a "Devices" section right after "Emulators" and before "Queue". `berth status` and the TUI stay as they are: the ticket names the panel's list, and the mirror button only exists there. (autopilot assumption)
- Source: the daemon already runs `adb devices` on every reap tick (5 s) for its own slots. It switches to `adb devices -l` and publishes the non-emulator entries in `StateSnapshot` as a new list of devices (serial, model from the `model:` field, adb state). The field is read with `decodeIfPresent`, so an older daemon or client still works. One process polls adb, not two, and berth-bar keeps getting everything from the daemon watch. Android devices are listed whatever the pool holds, including an iOS-only or empty pool (decided at validation: otherwise the panel would say "none connected" with a phone plugged in). (autopilot assumption)
- A physical device is any `adb devices` entry whose serial does not start with `emulator-`. This includes Wi-Fi devices (`192.168.x.y:5555`, `adb-…._adb-tls-connect._tcp`). (autopilot assumption)
- Each row shows the serial, the model and the adb state. A device in `unauthorized` or `offline` state is listed too, so the user sees why it cannot be used, but it gets no mirror button. A device with no `model:` field shows `—`. (autopilot assumption)
- Mirror: the row's button starts scrcpy in control mode (read write) through the existing `MirrorController`, with the same window title shape as emulators (`<serial> <model>`). It is never switched to view-only, since nobody leases a physical device. A second click brings the open window to front, as for emulators. (autopilot assumption)
- Empty list: the section shows "none connected", like "none running" and "empty" for the other sections. (autopilot assumption)
- No claim or release: physical devices never become broker slots, never appear in `berth claim` grants and never count against `maxRunning`. The broker already ignores non-emulator serials; this stays true.

## Acceptance criteria

- With a phone connected over USB and authorized, the berth-bar panel shows a "Devices" section below "Emulators" with one row: its serial, its model and the state `device`.
- The row's mirror button opens a scrcpy window for that phone, and input in that window reaches the phone (no `--no-control`).
- An unauthorized device is listed with the state `unauthorized` and no mirror button.
- With no phone connected, the "Devices" section shows "none connected".
- Emulators started by berth never appear in the "Devices" section, and the phone never appears under "Emulators".
- `berth claim` never grants the phone, and `berth status` output is unchanged.
- The panel render test covers a snapshot with one device row; `swift build` and `swift test` pass.

## Implementation

- `PhysicalDevice` (serial, optional model, `AdbState` enum: device, unauthorized, offline, other(String), Codable as the raw adb word) in `Sources/BerthCore/PhysicalDevice.swift`; `StateSnapshot.devices`, read with `decodeIfPresent` (empty for an older daemon).
- `DeviceListing.parse(adbDevices:)` (`Sources/BerthDaemon/Backends/DeviceListing.swift`) splits one `adb devices -l` output into the live emulator serials and the physical devices (every serial not starting with `emulator-`; model from `model:`, nil when absent).
- `DeviceBackend.listing()` with a default that wraps `liveSerials()`; `AndroidBackend` runs `adb devices -l` once per call and `liveSerials()` delegates to it; `DeviceRouter`: live serials come from the pool's platforms only (nil when one of them is unknown); Android devices are always added, and a failed Android poll outside the pool is ignored. `liveSerials()` = `listing()?.live`.
- `Broker.restore()` / `reap()` use `listing()`; the broker keeps the device list, `snapshot()` publishes it, and `reap()` calls `changed()` when the list differs, so watchers see it within one tick (5 s). A failed adb poll keeps the last list.
- Panel: "Devices" section between "Emulators" and "Queue" (`StatusPanel`), new `DeviceRow` (serial with hover help, model or `—`, state, mirror button aligned with the emulator column; widths shared with `EmulatorRow` through `PanelColumns`), "none connected" when empty. `MirrorController.open(_ device:)` starts scrcpy in control mode (title `<serial> <model or serial>`) and shares the activate-or-start logic with slots; `MirrorEligibility.showsMirrorButton(_ device:)` = state `.device`.
- Tests: `DeviceListingTests`, `DeviceRouterTests` (merge, iOS-only pool, empty pool, failed Android poll), `MirrorEligibilityTests` (device shown; unauthorized, offline, other hidden), broker tests (devices published, never slots or grants, unplug leaves on next reap), decoding of old snapshots, mirror controller (control mode, serial title, second open activates, `apply` leaves the device session alone), panel render (devices light + dark, empty).
- Build: `swift build` green, full `swift test` green, 0 new warnings.

## Review

### validation (autopilot) — 2026-11-12

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict after 3 rounds: clean.

Round 1, 7 findings (all 🟡), all fixed by autofix:
- [correctness] `DeviceRouter.listing()` asked only pool platforms: an iOS-only or empty pool never listed the phone. Fixed: Android devices always listed, `live` stays pool-gated.
- [structure] `liveSerials()` duplicated the `listing()` loop, merge untested. Fixed: `liveSerials()` = `listing()?.live`, router tests added.
- [correctness] `showsMirrorButton(_ device:)` untested. Fixed: `MirrorEligibilityTests` cases.
- [elegance] `state: String` + literal `"device"`. Fixed: `AdbState` enum.
- [structure] `DeviceRow` hard-coded 382 pt span. Fixed: shared `PanelColumns`.
- [style] new `BrokerTests` cases: `@Test` placement, names, untyped locals. Fixed (older tests untouched).
- [style] `String(fields[0])` → `.init(fields[0])`. Fixed.

Round 2, 1 finding: 🟡 [style] untyped `FakeBackend()` locals in the new router tests. Fixed.
Round 3: clean. Withdrawn: 0. Disputed: 0.

## Verification

- ✅ Own daemon (`BERTH_HOME=/tmp/b13`, pool `Pixel_9`, then empty pool, then iOS-only pool after autofix): `berth status --json` → `devices: [{"model":"SM_S901B","serial":"R3CT312YV5B","state":"device"}]`, `slots: []`.
- ✅ The running `emulator-5554` is not in `devices` and not adopted as a slot.
- ✅ `berth status` human table unchanged.
- ✅ Render `live-devices.png`: "Devices" between Emulators and Queue, `device` rows with the mirror button, `unauthorized` row with `—` and no button, no overflow at 650 pt. `live-empty.png`: "none connected".
- ✅ Unit: device mirror launches without `--no-control`; second click activates the open session.
- Not proven by the agent: input in the scrcpy window reaching the phone, and the popover on screen (desktop proof rules: no click, no focus taken).
