---
issue: 1
phase:
wiki: [[architecture]], [[cli]]
note:
created: 2026-10-14
---

## Context / Decisions

User request: "tray app to see what's running". The wiki already plans it: a SwiftUI `MenuBarExtra` app reusing the `BerthCore` client and the `watch` stream.

Prior art: `MenuBarExtra` (SwiftUI, macOS 13+) is the native API for a menu bar item; no third-party library is needed. The daemon already pushes a full `StateSnapshot` on `watch` (once on subscribe, then on every change), so the app needs no new protocol.

- **Where it lives.** A new SwiftPM executable target `BerthBar` under `Sources/BerthBar/`, product `berth-bar`, depending on `BerthCore` only (never on `BerthDaemon`). Files grouped by feature: `App/` (app entry), `Status/` (observable model and views). A test target `BerthBarTests` mirrors it. (autopilot assumption)
- **Plain executable, no `.app` bundle.** Built with `swift build`, launched as `berth-bar` (or `swift run berth-bar`). The app sets the activation policy to `.accessory` at launch, so it has no Dock icon and no main window. Packaging as a signed `.app` and launch at login are out of scope (YAGNI). (autopilot assumption)
- **Read-only.** The app shows state; it does not release, stop or claim. The user asked to "see what's running"; `berth top` keeps the actions. (autopilot assumption)
- **Never starts the daemon.** The app connects with `autoSpawn: false`: `DaemonClient.spawnDaemon` launches the current executable with `daemon run`, which inside `berth-bar` would launch the app itself, not the daemon. When the daemon is not running, the panel says so and the app keeps retrying every second, like `berth top`. (autopilot assumption)
- **Menu bar label.** An SF Symbol plus `<leased>/<running>` (emulators leased / emulators running). When claims are waiting, the label appends the queue length (for example `2/3 +1`). When the daemon is unreachable, the label shows the symbol alone, in a "disconnected" variant. (autopilot assumption)
- **Panel content** (`.menuBarExtraStyle(.window)`): a header with `<running>/<maxRunning> running · <n> waiting`; an Emulators section with one row per slot (serial, AVD, state, owner, label, held time, remaining TTL), state shown with a color per state like `berth top`; a Queue section with one row per waiter (position, owner, label, AVD or "any", waiting time); empty sections show "none running" / "empty"; a Quit button. Held and waiting times refresh every second, not only on daemon events. (autopilot assumption)
- **Shared code, no duplication.**
  - The reconnecting watch loop that `berth top` runs today moves into `BerthCore` as one public API that yields either a snapshot or a disconnection reason, with a parameter for `autoSpawn`. `berth top` and the app both use it. (autopilot assumption)
  - The duration formatters `StatusRenderer.clock` and `StatusRenderer.remaining` move into `BerthCore` as public helpers, used by `StatusRenderer` and the app. `berth status` and `berth top` output must not change. (autopilot assumption)
- **Tests.** Swift Testing on the pure logic: the menu bar label text (connected, queue non-empty, disconnected) and the moved duration formatters. SwiftUI views are not unit tested.
- **Docs.** README gets a short `berth-bar` section (build, launch); the wiki `architecture` page lists the new target.

## Acceptance criteria

- `swift build` builds a `berth-bar` executable, and `swift test` passes.
- Launching `berth-bar` adds a berth item to the menu bar and no Dock icon.
- With the daemon running and no emulator, the label reads `0/0` and the panel shows "none running" under Emulators and "empty" under Queue.
- With an emulator leased (for example `berth run --avd <AVD> --label demo -- sleep 120`), within about two seconds the label reads `1/1` and the panel lists that emulator's serial, AVD, state `leased`, owner, label `demo`, held time and remaining TTL.
- A claim waiting in the queue appears under Queue with its position, owner, label, AVD (or "any") and waiting time, and the label shows the queue length.
- When the daemon is not running, `berth-bar` does not start it; the panel says the daemon is not running, and the app shows live state again on its own within a few seconds once the daemon starts.
- The Quit button in the panel exits the app.
- `berth status` and `berth top` output is unchanged.
- README documents how to build and launch `berth-bar`.

## Implementation

## Review

## Verification

## Feedback
