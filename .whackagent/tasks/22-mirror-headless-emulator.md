---
issue: 22
phase:
wiki: [[architecture]]
note: Depends on #19 (PR #21): needs `Slot.windowed` and the reworked `EmulatorRow`. Code after #21 merges.
created: 2026-10-19
---

## Context / Decisions

User request (2026-10-19): "Integrate scrcpy or equivalent to show windowless emulator. Add a button in tray menu for that". The tray menu is the `berth-bar` panel. berth boots agent emulators with `-no-window`, and a running emulator cannot gain a window without a restart, which would lose its state. A mirror over adb shows its screen without touching how it runs.

Prior art (surveyed before building):
- scrcpy (Genymobile, Homebrew `scrcpy`, 5.0.1 on the dev Mac): mirrors any adb device, emulators included, in its own window, with `-s <serial>`, `--no-control`, `--no-audio`, `--window-title`. Fits: berth writes no video code. Chosen.
- Emulator gRPC `streamScreenshot`: no external tool, but needs a hand-rolled gRPC/protobuf client, a frame view in `berth-bar` and new launch flags. Rejected: too much custom code.
- `adb exec-out screenrecord` piped to a player: lags and stops after 3 minutes. Rejected.
- Bundling scrcpy in berth releases: berth would then own its updates, license and signing. Rejected.

User answers (2026-10-19):
- **scrcpy is an external dependency.** `berth-bar` looks for it on `PATH`, then in `/opt/homebrew/bin` and `/usr/local/bin`, because a menu bar app started by launchd gets a minimal `PATH`. It runs scrcpy with `ADB` set to the SDK adb (`<Config.resolvedSDKRoot>/platform-tools/adb`), so scrcpy talks to the same adb server as berth. scrcpy not found → the click opens nothing and the panel shows one caption line: `scrcpy not found: brew install scrcpy`.
- **Input on free slots only.** A mirror opened on a `free` slot has full control (taps, keys). A mirror opened on a `leased` slot is view-only (`--no-control`).
- **Free → leased while mirrored.** scrcpy cannot switch control off in a running window. When the snapshot shows a mirrored slot going from `free` to `leased` while its mirror has control, `berth-bar` stops that scrcpy and starts a new one with `--no-control` at once. The window blinks once. When the lease ends and the slot is free again, the view-only mirror stays view-only. Reopen it to get control back (YAGNI).
- **A touched free slot is not reset.** The next claim gets it in its current state, like a released manual emulator in #19. No daemon change, no new protocol verb.
- **Which rows.** The Mirror button shows on headless Android slots (`slot.windowed == false`, platform from the pool via `Config.platform(of:)` / `snapshot.pool`) in state `free` or `leased`. No button on windowed slots (#19), on iOS simulators, or on `booting`, `resetting` and `stopping` slots.
- **One mirror per emulator.** `berth-bar` keeps the scrcpy process for each serial. A click while a mirror is open for that serial opens no second one: it brings the existing window to front (`NSRunningApplication(processIdentifier:)?.activate()`).
- **Reset or stop.** A reset is a restart, so adb loses the device and scrcpy exits on its own. `berth-bar` sees the process exit and forgets it. No auto-reopen after a reset (YAGNI).
- **Quit.** When `berth-bar` quits, it stops every scrcpy it started, by pid. It never touches a scrcpy it did not start.
- **Dependency on #19.** PR #21 (#19) adds `Slot.windowed` and a Release button to the same `EmulatorRow`, which is already about 620 pt wide. #22 depends on #19 and is coded after #21 merges. It forks from `main`, not stacked: the two tickets share no sprint.
- **Button.** Icon-only button, SF Symbol `play.display`, tooltip "Mirror", in a new trailing column of about 22 pt after the remaining-time column. Rows without the button keep the empty column so the columns stay aligned. The panel grows from 620 pt to 650 pt.

Decisions settled from the code and the rules above:
- **Window title** = `<serial> <model>`, plus ` (view only)` for a `--no-control` mirror, so the user sees which emulator it is and whether input works. Every mirror passes `--no-audio`: audio capture is not asked for, and it would take the host audio output.
- **Process.** scrcpy runs as a child of `berth-bar` (Foundation `Process` with a termination handler, not `Spawn.detached`): `berth-bar` owns it, must see it exit and stops it on quit. Its stdout and stderr go to `<Paths.logs>/mirror-<serial>.log`.
- **Failure caption.** scrcpy exit code 0 (window closed) or 2 (device disconnected, as on a reset) is normal and shows nothing. Any other exit code that `berth-bar` did not cause (not its own stop on quit or on the free → leased switch) shows one caption line: `mirror <serial> failed, see <log path>`. The caption clears on the next mirror click.
- **Daemon untouched.** The mirror is a `berth-bar` feature only: no protocol, broker or backend change.
- **Where it lives.** New feature folder `Sources/BerthBar/Mirror/`:
  - a scrcpy locator (search order above, injectable search paths for tests),
  - a pure argument builder (serial, model, control or not → scrcpy arguments),
  - an `@Observable @MainActor` mirror controller: one process per serial, control flag, open or bring to front, react to snapshot changes (free → leased switch), forget on exit, stop all on quit, caption state.
  The controller is created in `App/BerthBarDelegate.swift` and handed down like the #19 launcher. It observes `StatusModel` snapshots. `Panel/EmulatorRow.swift` only binds the button and `Panel/StatusPanel.swift` shows the caption. Quit (`applicationWillTerminate`) stops the mirrors.
- **Tests.** `Tests/BerthBarTests/Mirror/` mirrors the source folder: the locator finds scrcpy in the first search path that has it and returns nil when none has it; the argument builder adds `--no-control` and ` (view only)` only for leased slots, and always `-s <serial>` and `--no-audio`; the controller, with a fake process launcher, opens one mirror per serial, brings an open one to front on a second click, restarts it view-only on free → leased, does not restart a view-only mirror, forgets it on exit, shows the caption only for other exit codes, and stops all its mirrors on quit. `StatusPanelRenderTests` gets a state with a free headless slot, a leased headless slot, a windowed slot and an iOS slot, to show which rows get the button.
- **Runtime proof.** scrcpy opens a window, which takes focus, so the agent never opens a real mirror (`CLAUDE.md#Desktop proofs`). The panel is proven by the render tests. A human checks the click, the window, input on a free slot, the free → leased switch, a reset closing the window, and Quit closing the mirrors.
- **Docs.** README "Menu bar": the Mirror button, scrcpy as an optional dependency (`brew install scrcpy`), input only on free slots. Wiki `architecture`: the `BerthBar/Mirror/` folder and that `berth-bar` starts scrcpy children.

## Acceptance criteria

- `swift build` and `swift test` pass.
- In the `berth-bar` panel, each headless Android emulator row in state `free` or `leased` shows a Mirror button (icon `play.display`, tooltip "Mirror") in a trailing column. Windowed emulators, iOS simulators, and `booting`, `resetting` or `stopping` rows show no button, and the columns stay aligned at a panel width of 650 pt.
- With scrcpy installed, clicking Mirror on a `leased` headless emulator opens a scrcpy window titled `<serial> <model> (view only)` that shows the emulator screen and ignores clicks and keys.
- Clicking Mirror on a `free` headless emulator opens a scrcpy window titled `<serial> <model>` that accepts clicks and keys.
- scrcpy is found when `berth-bar` is started by launchd (Launch at login) with Homebrew's scrcpy in `/opt/homebrew/bin` or `/usr/local/bin`.
- Clicking Mirror again on an emulator whose mirror is open opens no second window and brings the existing one to front.
- When an agent claims a free emulator whose mirror has control, the mirror closes and reopens at once as view-only.
- A free emulator touched through a mirror goes to the next claim as is, without reset.
- When a mirrored emulator is reset (release) or stopped, its mirror window closes, the panel shows no error, and the Mirror button opens a fresh mirror once the emulator is `free` or `leased` again.
- Without scrcpy, clicking Mirror opens nothing and the panel shows `scrcpy not found: brew install scrcpy`.
- A scrcpy that fails for another reason shows `mirror <serial> failed, see <log path>` in the panel, and its output is in that log.
- Quitting `berth-bar` closes every mirror it opened, and no other scrcpy process.
- The daemon, the CLI and the agent emulators behave exactly as before: no protocol change.
- README documents the Mirror button and the scrcpy install.

## Implementation

## Review

## Verification

## Feedback
