---
issue: 1
phase: review
wiki: [[architecture]], [[cli]]
note:
created: 2026-10-14
---

## Context / Decisions

User request: "tray app to see what's running". The wiki already plans it: a SwiftUI `MenuBarExtra` app reusing the `BerthCore` client and the `watch` stream.

Prior art: `MenuBarExtra` (SwiftUI, macOS 13+) is the native API for a menu bar item; no third-party library is needed. Feedback round 1 replaced it with AppKit `NSStatusItem` + `NSPopover` hosting the SwiftUI panel, because a `MenuBarExtra` in `.window` style never opened its panel on click (see `## Feedback`). (autopilot assumption) The daemon already pushes a full `StateSnapshot` on `watch` (once on subscribe, then on every change), so the app needs no new protocol.

- **Where it lives.** A new SwiftPM executable target `BerthBar` under `Sources/BerthBar/`, product `berth-bar`, depending on `BerthCore` only (never on `BerthDaemon`). Files grouped by feature: `App/` (app entry), `Status/` (observable model and views). A test target `BerthBarTests` mirrors it. (autopilot assumption)
- **Plain executable, no `.app` bundle.** Built with `swift build`, launched as `berth-bar` (or `swift run berth-bar`). The app sets the activation policy to `.accessory` at launch, so it has no Dock icon and no main window. Packaging as a signed `.app` and launch at login are out of scope (YAGNI). (autopilot assumption)
- **Read-only.** The app shows state; it does not release, stop or claim. The user asked to "see what's running"; `berth top` keeps the actions. (autopilot assumption)
- **Never starts the daemon.** The app connects with `autoSpawn: false`: `DaemonClient.spawnDaemon` launches the current executable with `daemon run`, which inside `berth-bar` would launch the app itself, not the daemon. When the daemon is not running, the panel says so and the app keeps retrying every second, like `berth top`. (autopilot assumption)
- **Menu bar label.** An SF Symbol plus `<leased>/<running>` (emulators leased / emulators running). When claims are waiting, the label appends the queue length (for example `2/3 +1`). When the daemon is unreachable, the label shows the symbol alone, in a "disconnected" variant. (autopilot assumption)
- **Panel content** (a transient popover under the item): a header with `<running>/<maxRunning> running · <n> waiting`; an Emulators section with one row per slot (serial, AVD, state, owner, label, held time, remaining TTL), state shown with a color per state like `berth top`; a Queue section with one row per waiter (position, owner, label, AVD or "any", waiting time); empty sections show "none running" / "empty"; a Quit button. Held and waiting times refresh every second, not only on daemon events. (autopilot assumption)
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

Brick 1 — shared code in `BerthCore`, no behavior change:
- `Watch/DaemonWatch.swift`, `Watch/WatchUpdate.swift`: `DaemonWatch.updates(autoSpawn:)` is the reconnecting watch stream (1 s retry, cancelled on stream termination). `berth top` consumes it.
- `Format/DurationFormat.swift`: `clock` and `remaining`, moved from `StatusRenderer`.
- `Tests/BerthCoreTests/Format/DurationFormatTests.swift` (new test target `BerthCoreTests`).

Brick 2 — `berth-bar` (`Sources/BerthBar`, depends on `BerthCore` only):
- `App/BerthBarApp.swift`: `MenuBarExtra` in `.window` style, `.accessory` activation policy.
- `Status/StatusModel.swift`: `@Observable @MainActor`, `DaemonWatch.updates(autoSpawn: false)` plus a 1 s tick.
- `Status/MenuBarLabel.swift` (label text logic), `MenuBarLabelView.swift` (`iphone` / `iphone.slash` symbol), `StatusPanel.swift`, `EmulatorRow.swift`, `QueueRow.swift`, `SlotState+Color.swift`.
- `Tests/BerthBarTests/Status/MenuBarLabelTests.swift`.
- README "Menu bar" section; wiki `architecture` page lists `BerthBar`, `Watch`, `Format`.

Build: `swift build` green. Tests: `swift test` 27 passed (16 broker, 6 duration format, 5 menu bar label).

## Review

### validation (autopilot) — 2026-10-14

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean after 3 rounds.

Round 1 found 7 issues, all fixed by autofix:
- major, correctness: the emulator row overflowed the panel, so the held time and TTL were truncated. The panel is now 620 pt wide and those two columns have fixed widths.
- minor, elegance: the connection state was held in two linked optionals. It is now one `StatusState` enum (`connecting` / `live` / `disconnected`), and the panel shows "connecting…" before the first snapshot.
- minor, structure: the header line was duplicated with `berth status`. It is now a shared `StateSnapshot.summary` in BerthCore.
- minor, elegance: `berth top` re-mapped `WatchUpdate` into its own cases. It now uses `UIEvent.watch(WatchUpdate)`.
- minor, structure: the `Status/` folder was flat. It is now split into `MenuBar/`, `Panel/` and `Status/`, and the tests mirror that.
- minor, style: `DaemonWatch` lacked explicit types. They are added.
- minor, style: the test helpers were out of member order and built models inline. Tests now use internal `mock(...)` helpers in `Model.swift`.

Round 2 found 2 issues, both fixed:
- minor, elegance: a failed release or stop in `berth top` was reported as a watch disconnection. It now has its own `actionFailed` event.
- minor, style: the mock defaults repeated the type name. They now use `.init(...)`.

Round 3: clean.

## Verification

Runtime check by agent, `BERTH_HOME=/tmp/bb1`, pool `Emu_2` only:
- ✅ `swift build` produces `berth-bar`; `swift test` passes.
- ✅ Daemon down: `berth-bar` stays alive, creates no socket and starts no `berth daemon run`; label shows the slashed symbol without a count.
- ✅ Menu bar item present (System Events lists a status menu for `berth-bar`; screenshots).
- ✅ Daemon started afterwards: label switches to `0/0` within 3 s (reconnect).
- ✅ Leased emulator (`berth run --avd Emu_2 --label demo -- sleep 120`) plus queued claim: label `1/1 +1`; `berth status` shows `emulator-5556 Emu_2 leased demo` and queue #1.
- ✅ `berth status` text output byte-identical to `main`; `--json` identical except `generatedAt`.
- ❌ Not seen: panel content (rows, "none running" / "empty", "daemon not running"). Automation could not open the `MenuBarExtra` window (click and `AXPress` returned success, no window).
- ❌ Not run: Quit button (inside the panel).
- ❌ Not checked: no Dock icon (relies on `.accessory`).
- After autofix: the agent relaunched the app; the disconnected label (slashed symbol) and reconnect to `0/0` were seen again, and `berth status` was again byte-identical to `main`. The panel still could not be opened by automation.

Feedback round 1 — runtime check by agent, with no mouse, keystroke or focus change. The panel was opened and closed by Accessibility `AXPress` addressed by pid. Screenshots were window-scoped with `screencapture -l`. `BERTH_HOME=/tmp/bb1`, pool `Emu_2` only, device lock held.
- ✅ Daemon down: the panel shows "daemon not running", the reason and Quit. No daemon was spawned.
- ✅ Live, empty: "0/1 running · 0 waiting", "none running", "empty".
- ✅ Leased plus queued: "1/1 running · 1 waiting". The emulator row shows `emulator-5556 Emu_2 leased(cyan) berth#76470 demo 0:09 59m` and the queue row shows `1 berth#76600 waiter Emu_2 0:17`, nothing truncated. The label reads `1/1 +1`.
- ✅ Quit: pressing the Quit button by pid ends the process.
- ✅ The `berth status` format is identical to `main`.
- The popover opened without taking focus. Frontmost app and cursor were sampled, but changes between samples could not be told apart from the user's own activity.
- Not proven: a real mouse click. This was not run, by design.

## Feedback

### Round 1 — 2026-10-14

**Asked**: "Open popup UI on click to see devices state (claim, running, etc)"

**Triage**: defect. Clicking the menu bar item did not open the panel, so the panel criteria failed. The acceptance criteria are unchanged.

**Root cause**: the SwiftUI `MenuBarExtra` in `.window` style never opened its panel. The status item received `performClick:`, but no window was created and the panel's `onAppear` never ran. An 8-line `MenuBarExtra(.window)` app behaved the same. The two first suspects were tried and ruled out: moving `setActivationPolicy` out of `App.init`, and embedding an `Info.plist` with `LSUIElement`. A hand-written `NSStatusItem` + `NSPopover` opens under the same press.

**What changed** (route: implementer):
- `App/BerthBarApp.swift` keeps only an `@NSApplicationDelegateAdaptor` and an empty `Settings` scene.
- `App/BerthBarDelegate.swift` (new) sets the `.accessory` policy at launch and creates the controller.
- `MenuBar/StatusItemController.swift` (new) owns the `NSStatusItem`. It toggles a transient `NSPopover` that hosts `StatusPanel`, and refreshes the icon and title through `withObservationTracking`.
- `MenuBarLabel.symbolName(for:)` added. `MenuBarLabelView.swift` removed.
- The wiki `architecture` line was updated.

**Review**: deferred to `/wa-validate`.

**Verify**: ✅. The details are in `## Verification`, round 1.

