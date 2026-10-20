---
issue: 29
phase: in-progress
wiki: [[architecture]], [[ios-backend]]
note: Autopilot grill (AFK). Open PR #28 (#25) touches StatusPanel.swift, StatusPanelRenderTests.swift, BerthBarDelegate.swift, README and wiki architecture: merge conflict likely, mechanical.
created: 2026-10-20
---

## Context / Decisions

User request (2026-10-20): "need a way to controle iOS simulator (equivalent of scrcpy for android)". #22 added a Mirror button on headless Android rows of the `berth-bar` panel that opens scrcpy. berth boots its iOS simulators headless (`simctl boot`, no Simulator window), so a human cannot see or touch them today.

Prior art (surveyed on the dev Mac, Xcode 27.1, macOS 27):
- Xcode 27 removes Simulator.app. Its replacement is DeviceHub (`/Applications/Xcode-27.1.0.app/Contents/Applications/DeviceHub.app`, bundle id `com.apple.dt.Devices`). It registers the URL scheme `devices`.
- `open "devices://device/open?id=<udid>"` opens a compact DeviceHub window for that one simulator, titled with the device name (`berth-iPhone 18 Pro-2`). It attaches to a simulator that `simctl` booted headless, without rebooting it, and shows its live screen with full input. Proven on the dev Mac on a booted `berth-` simulator (DeviceHub log: `URL … successfully handled by provider`). `devices://manage/select?id=<udid>` only selects the device in the main window, and `device/open?deviceIdentifiers=<udid>` is refused (`failed to parse parameters`).
- DeviceHub has a "Stop simulators on quit" setting, but it applies only to simulators DeviceHub started itself. berth simulators are booted by `simctl`, so quitting DeviceHub should leave them running (to be confirmed by a human).
- `simctl io <udid> screenshot` polled into a custom window: view only, no input without private frameworks. Rejected.
- idb (`idb_companion`): extra install, private frameworks, little maintenance. Rejected.
- DeviceHub URLs are not documented by Apple. The `devices://manage/select?id=` form comes from a third-party report (Tuist); `device/open?id=` was found in DeviceKit's URL action table and proven by hand.

Decisions (autopilot, nobody to ask):
- **DeviceHub is the iOS mirror.** It ships with Xcode, so there is no new dependency. `berth-bar` opens `devices://device/open?id=<udid>` with `NSWorkspace`. DeviceHub comes to front, because the user clicked. (autopilot assumption)
- **No Simulator.app fallback.** Xcode 26 or older has no DeviceHub. Then the click opens nothing and the panel shows `DeviceHub not found: needs Xcode 27`. Supporting Simulator.app (`-CurrentDeviceUDID`) cannot be tested on this Mac, so it is left out (YAGNI). It can be added later. (autopilot assumption)
- **Which rows.** The Mirror button also shows on iOS simulator rows in state `free` or `leased`. Platform comes from the pool (`[PoolEntry].platform(of:)`), as for Android. No button on `booting`, `resetting` or `stopping` rows. iOS simulators are never windowed. (autopilot assumption)
- **Input on leased simulators.** DeviceHub has no view-only mode, so a mirror on a leased simulator accepts input, unlike the Android view-only mirror. Watching an agent's simulator is the main use, so the button stays on leased rows. Its tooltip warns: `Mirror in DeviceHub (input reaches the agent's simulator)`. On a free row the tooltip is `Mirror in DeviceHub`. Android tooltips stay `Mirror`. (autopilot assumption)
- **berth-bar owns no DeviceHub process.** DeviceHub is the user's app. `berth-bar` keeps no session for iOS mirrors: no free → leased switch, nothing stopped on Quit, no exit tracking. DeviceHub itself keeps one window per device, so a second click brings that window back.
- **Reset and stop.** A release resets the simulator (`shutdown` + `erase` + `boot`). DeviceHub shows what happens to the device. No berth code reacts to it.
- **Failure.** `NSWorkspace` reports an error when opening the URL → the panel shows `mirror <udid> failed: <error>`. The caption clears on the next Mirror click, as for Android.
- **A touched free simulator is not reset** before the next claim, as for Android. Every claim of an iOS simulator already starts with `erase` + `boot` (see [[ios-backend]]), so the next agent gets a clean device anyway.
- **Daemon untouched.** `berth-bar` only: no protocol, broker or backend change.
- **Where it lives.** In `Sources/BerthBar/Mirror/`:
  - a pure URL builder: UDID → `devices://device/open?id=<udid>`;
  - a small opener protocol over `NSWorkspace` (is there an app for the `devices` scheme, open this URL with completion), with a system implementation and a fake for tests;
  - `MirrorController.open` routes by platform: iOS → the opener, Android → scrcpy unchanged;
  - `MirrorEligibility` accepts iOS slots in `free` or `leased`.
  - `EmulatorRow` picks the tooltip by platform and state.
- **Tests.** In `Tests/BerthBarTests/Mirror/`: the URL builder; the controller opens the DeviceHub URL for an iOS slot and never calls the scrcpy launcher for it; it shows `DeviceHub not found: needs Xcode 27` when no app handles `devices`; it shows the failure caption when opening fails; `apply` and `stopAll` leave iOS slots alone. `MirrorEligibilityTests`: iOS `free` and `leased` get the button, iOS `booting`, `resetting` and `stopping` do not. `StatusPanelRenderTests`: the iOS row in the existing state now shows the button.
- **Runtime proof.** Opening DeviceHub from the panel needs a click on the popover, which takes focus, so the agent never does it (`CLAUDE.md#Desktop proofs`). The DeviceHub URL was proven by hand during the grill (above). The panel is proven by the render tests. A human checks the click, the window, input, a reset while mirrored, and quitting DeviceHub.
- **Docs.** README "Menu bar": iOS rows get the Mirror button too, it opens DeviceHub (Xcode 27), and input works on leased simulators. Wiki [[architecture]] (BerthBar/Mirror) and [[ios-backend]] (DeviceHub mirror).

## Acceptance criteria

- `swift build` and `swift test` pass.
- In the `berth-bar` panel, each iOS simulator row in state `free` or `leased` shows the Mirror button (icon `play.display`). iOS rows in `booting`, `resetting` or `stopping` show no button. Android rows keep their current buttons.
- The tooltip of the iOS Mirror button is `Mirror in DeviceHub` on a free row and `Mirror in DeviceHub (input reaches the agent's simulator)` on a leased row.
- With Xcode 27 installed, clicking Mirror on an iOS row opens a DeviceHub window for that simulator only, showing its live screen, and clicks and keys reach the simulator.
- Opening the mirror does not reboot, erase or release the simulator: its lease, state and running apps stay as they were.
- Clicking Mirror again on the same simulator opens no second window for it.
- Closing the DeviceHub window or quitting DeviceHub leaves the simulator booted and its lease untouched.
- Without an app that handles `devices://` URLs (no Xcode 27), clicking Mirror on an iOS row opens nothing and the panel shows `DeviceHub not found: needs Xcode 27`.
- When opening the DeviceHub URL fails, the panel shows `mirror <udid> failed: <error>`.
- Quitting `berth-bar` does not close DeviceHub.
- The Android mirror (scrcpy) behaves exactly as before.
- The daemon, the CLI and the berth simulators behave exactly as before: no protocol change.
- README documents the iOS Mirror button and that it needs Xcode 27 (DeviceHub).
