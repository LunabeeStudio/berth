---
issue: BERTH-13
phase:
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
- Source: the daemon already runs `adb devices` on every reap tick (5 s) for its own slots. It switches to `adb devices -l` and publishes the non-emulator entries in `StateSnapshot` as a new list of devices (serial, model from the `model:` field, adb state). The field is read with `decodeIfPresent`, so an older daemon or client still works. One process polls adb, not two, and berth-bar keeps getting everything from the daemon watch. (autopilot assumption)
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
