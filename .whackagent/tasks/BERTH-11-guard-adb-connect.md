---
issue: BERTH-11
phase: grilled
type: fix
wiki:
note:
created: 2026-11-02
---

## Context / Decisions

Ticket: the guard denies `adb connect 192.168.4.35:5555` with "adb without -s targets whatever device is connected". `adb connect` takes no serial, so an agent cannot attach a physical phone over Wi-Fi at all. User (2026-11-02): "It should not block non-emulator device".

Decisions (2026-11-02):
- `connect`, `disconnect`, `pair` and `mdns` join the untargeted adb subcommands. They only manage network (TCP) devices and never reach a local emulator, whose transport is not a TCP connect.
- Everything else stays as is: `adb -e`, `kill-server`, `emu kill` and untargeted device commands (`shell`, `install`, `logcat`, …) are still denied. A physical device stays reachable with `-s <serial>` or `-d`, as before.
- No runtime check of which devices are attached: the guard stays static (YAGNI).

## Acceptance criteria

- `adb connect <ip>:<port>`, `adb disconnect <ip>:<port>`, `adb pair <ip>:<port> <code>` and `adb mdns services` are allowed without `-s`.
- `adb install app.apk`, `adb shell …`, `adb -e shell ls`, `adb kill-server` and `adb -s emulator-5554 emu kill` are still denied.
- `swift test --filter DeviceCommandGuardTests` passes.
