---
issue: 5
phase: validated
wiki: [[architecture]]
note: Prior art Kokoriko #155 (LunabeeStudio/kokoriko PR #167, tools/desktop/kokoriko-ui-window.swift, CLAUDE.md "Desktop UI proofs").
created: 2026-10-16
---

## Context / Decisions

User idea (2026-10-14): runtime proofs of `berth-bar` (#1) must not take over the user's mouse, keyboard or frontmost app. During #1 the implementer used osascript / System Events clicks and full-screen `screencapture`, which brought another app's window to the front and captured unrelated terminals. Same approach as Kokoriko #155, adapted to SwiftUI.

Since the issue was written, #1 replaced the SwiftUI `MenuBarExtra` with an AppKit `NSStatusItem` + `NSPopover` (`StatusItemController`). Its `toggle` calls `NSApp.activate()` before showing the popover, so opening the panel by any means (a click or an Accessibility `AXPress` on the status item) takes the user's focus. That is why panel content must be proven in-process.

Prior art: Kokoriko #155 ships `tools/desktop/kokoriko-ui-window.swift` (window id by pid from `CGWindowListCopyWindowInfo`, `desk-state` as one JSON line) and a CLAUDE.md "Desktop UI proofs" rule. Its in-process driver (javaagent + file mailbox) is Compose-specific and is not needed here: `berth-bar` has a single panel whose content is a pure function of its state. No library offers window capture by pid; `screencapture -l` is the system tool.

- **Written rule.** (autopilot assumption) A new `## Desktop proofs` section in `CLAUDE.md`, plus one line in the `.whackagent/config.md` project notes pointing to it. It says:
  - Desktop proofs never use CGEvent or System Events clicks or keystrokes, `cliclick`, `osascript … activate`, or `screencapture` without `-l`, and never address another pid or a window position.
  - No Accessibility action (`AXPress` or other) on `berth-bar`: pressing its status item opens the popover, which activates the app and takes the user's focus. Accessibility attribute reads addressed by pid (for example the status item title) are allowed, because they change nothing.
  - The proof launches its own `berth-bar` by path (`.build/debug/berth-bar`) in the background, records the pid, and stops it with `kill <pid>`. Never by name (`pkill`, `killall`): the user may run their own `berth-bar`.
  - `desk-state` is taken before and after each step.
  - Panel content is proven by the render tests, not on screen.
  - A human checks what cannot be proven without input: opening the popover with a real click, and the Quit button.
- **Desktop helper script.** (autopilot assumption) `tools/desktop/desk.swift`, run with `xcrun swift tools/desktop/desk.swift <command>`. It is a standalone script outside the SwiftPM package, like Kokoriko's, so `swift build` never compiles it and it adds no product dependency. Commands:
  - `desk-state` prints the frontmost app (pid and name) and the cursor position as one JSON line.
  - `window-id <pid>` prints the id of the largest on-screen window owned by that pid, at any layer. For `berth-bar` with the popover closed, that is its status item. A pid with no window prints nothing and exits 1.
  - `capture <pid> <out.png>` runs `screencapture -l <id> -o -x <out.png>` on that window. It exits 1 when the pid has no window.
  - Bad usage prints the usage to stderr and exits 2.
- **Panel render tests.** (autopilot assumption) `BerthBarTests` renders `StatusPanel` offscreen, one image per state: connecting, disconnected, live with no emulator and no queue, and live with a leased emulator plus a queued claim.
  - Rendering uses `NSHostingView` + `cacheDisplay(in:to:)`, not `ImageRenderer`: `ImageRenderer` draws AppKit-backed controls such as the Quit `Button` as placeholders. If `NSHostingView` cannot render in the test process, `ImageRenderer` is the fallback, and the implementer says so.
  - The appearance is fixed to light (`.aqua`) and the clock is fixed, so the images are deterministic. No pixel comparison against reference images: rendering changes between macOS versions (YAGNI).
  - Each test asserts that the image is non-empty and 620 pt wide (the panel width).
  - When the environment variable `BERTH_PANEL_PNG_DIR` is set, each test also writes `<state>.png` into that directory, so an agent or a human can look at the panel without opening it. Unset, nothing is written.
- **Test seam.** (autopilot assumption) `StatusPanel` stays bound to `StatusModel`. `StatusModel` gets an internal initializer that takes a fixed `StatusState` and `now` and starts no watch and no tick. The existing `init()` keeps its behavior (it watches the daemon with `autoSpawn: false` and ticks every second). No debug flag in `berth-bar`, no other product code change.
- **Out of scope.** Driving the popover or the Quit button on screen, dark appearance renders, and any change to the whackagent plugin.
- **Found while coding: the status item is not the app's window.** (Decided by the user on 2026-10-16 at `/wa-validate`: amend the criteria as recommended below. Done.) On this Mac (macOS 27), the `berth-bar` status item is drawn by `MenuBarAgent`, another process. The `berth-bar` pid owns only its popover window, which stays off screen while the popover is closed. So `window-id` and `capture` by pid cannot reach the status item, and the two criteria about it cannot pass as written. The code was not bent to reach the item through another pid or a screen region, because the rule forbids both. `window-id` and `capture` address the pid's own on-screen windows, for example the popover once a human has opened it. `CLAUDE.md` says the status item label is proven by an Accessibility title read addressed by pid, or by a human. Recommended amendment: replace the two status item criteria with "the status item title, read by Accessibility on the pid, is empty with the daemon down".

## Acceptance criteria

- `swift build` and `swift test` pass.
- `CLAUDE.md` has a `## Desktop proofs` section that states every rule listed under "Written rule" above, and the `.whackagent/config.md` project notes have one line that points to it.
- `xcrun swift tools/desktop/desk.swift desk-state` prints one JSON line with the frontmost app's pid and name and the cursor's x and y.
- For a pid that owns an on-screen window, `xcrun swift tools/desktop/desk.swift window-id <pid>` prints a window id and exits 0. For the pid of a process with no window, it prints nothing and exits 1.
- With the `berth-bar` popover opened by a human, `xcrun swift tools/desktop/desk.swift capture <pid> <out.png>` writes a PNG that shows only the popover, even when another app is in front. (Checked by a human.)
- Across launching `berth-bar`, `window-id`, `capture` and `kill <pid>`, the frontmost app reported by `desk-state` does not change.
- `swift test` runs a panel render test for each of the four states: connecting, disconnected, live empty, and live with a leased emulator plus a queued claim. Each produces a non-empty image 620 pt wide.
- With `BERTH_PANEL_PNG_DIR` set, the render tests write one PNG per state into that directory. The PNGs show readable text: "connecting…"; "daemon not running" with its reason; "none running" and "empty"; and the emulator row and queue row in full, not truncated. The Quit button is visible in each.
- `berth-bar` behaves as before: launched with the daemon down, it starts no daemon.
- With the daemon down, the `berth-bar` status item title, read by Accessibility addressed to the pid, is empty. (Checked by a human, because the agent's shell has no Accessibility access.)

## Implementation

Brick 1, panel render tests:
- `Sources/BerthBar/Status/StatusModel.swift`: new `init(state:now:)`, which starts no watch and no tick. `init()` is unchanged.
- `Tests/BerthBarTests/Panel/StatusPanelRenderTests.swift` (new): renders `StatusPanel` with `NSHostingView` + `cacheDisplay(in:to:)` in the `.aqua` appearance with a fixed clock. Four tests: connecting, disconnected, live empty and live busy. Each asserts a non-empty image 620 pt wide. With `BERTH_PANEL_PNG_DIR` set, each writes `connecting.png`, `disconnected.png`, `live-empty.png` or `live-busy.png` there. The `ImageRenderer` fallback was not needed.

Brick 2, desktop helper:
- `tools/desktop/desk.swift` (new): a standalone script outside the package. `desk-state` prints one JSON line, with `null` when a value is absent. `window-id <pid>` prints the largest on-screen window the pid owns. `capture <pid> <out.png>` runs `screencapture -l <id> -o -x`. Exit codes: 0 ok, 1 no window or failure, 2 bad usage.

Brick 3, written rule:
- `CLAUDE.md`: new `## Desktop proofs` section.
- `.whackagent/config.md`: one project note pointing to it.

Build: `swift build` green. Tests: `swift test` 10 passed (6 menu bar label, 4 panel render).

## Review

### validation (autopilot) — 2026-10-16

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: 1 finding open after 2 autofix rounds.

Round 1 found 6 issues. Five were fixed by autofix; the critical one is open:
- critical, correctness, **open**: the two criteria about the status item cannot pass on macOS 27. `MenuBarAgent` draws the status item, not a window of the `berth-bar` pid. Evidence: the user's running `berth-bar` owns one window only, the off-screen popover (layer 25, 646x207). The user decides how the criteria change; see `## Context / Decisions`. Autofix removed the false claim "with the popover closed, the window is the status item" from `CLAUDE.md`.
- minor, correctness: a forced cast on the window bounds could trap. It now binds with `as? NSDictionary`.
- minor, elegance: the manual loop with a `-1` sentinel is now `compactMap` + `max(by:)`.
- minor, elegance: `desk-state` printed `0`, `""` or `.zero` for absent values. It now prints `null`.
- minor, correctness: `capture` forwarded screencapture's raw status, and a thrown error trapped. Every failure now exits 1 with a message on stderr.
- minor, style: the header comment repeated the usage. It is down to three lines.

Round 2 found 1 new minor issue, fixed:
- minor, correctness: `CLAUDE.md` stated "the status item is drawn by `MenuBarAgent`" for every macOS. It now says this was seen on macOS 27, and that on older macOS `window-id` may return the status item.

Round 3: only the critical spec finding remains.

### validation — 2026-10-16

The user accepted the open critical finding and chose to amend the spec, with no code change.
- The two criteria about capturing the status item by pid are replaced. `window-id` is now proven on any on-screen window owned by the pid. `capture` is checked by a human on the popover once it is open.
- A new criterion covers the status item: its title, read by Accessibility on the pid, is empty with the daemon down. A human checks it.

The code is unchanged since the autopilot review, so the verifier was not re-run. Verdict: clean, with the finding accepted.

The rebase onto `main` (#9 Launch on login) then broke the render tests, so the round stopped. Feedback round 1 fixed them.

### validation (after feedback round 1) — 2026-10-16

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean after one autofix round. The verifier checked the whole ticket range after the rebase; it touches only its own files.

Round 1 found 1 minor issue, fixed by autofix:
- minor, structure: the render test duplicated the temporary `LaunchAgent` setup of `LaunchAtLoginTests`. Both suites now use `LaunchAgent.temporary(label:)` in `Tests/BerthBarTests/Login/LaunchAgent+Temporary.swift`.

Round 2: clean.

## Verification

Runtime check by agent, with no mouse, keystroke or focus change. `BERTH_HOME=/tmp/bb5`, daemon down, no emulator.
- ✅ `swift build` and `swift test` pass.
- ✅ `CLAUDE.md` has `## Desktop proofs`, and `.whackagent/config.md` has the pointer line.
- ✅ `desk-state` prints one JSON line, for example `{"cursor":{"x":…,"y":…},"frontmostName":"Terminal","frontmostPid":3100}`.
- ❌ `window-id <pid>` on the background `berth-bar` printed nothing and exited 1: the pid has no on-screen window (see the open finding). On an on-screen window (Terminal, pid 3100) it printed `1469` and exited 0. For pid 1 (no window) it printed nothing and exited 1. Bad usage exits 2.
- ❌ `capture` of the status item: not possible on macOS 27, for the same reason. `capture` was not run on another window.
- ✅ The frontmost app (Google Chrome, pid 1466) did not change across the launch, `window-id`, `capture` and `kill <pid>`. Only the cursor moved, from the user's own work.
- ✅ The 4 render tests pass. The PNGs show "connecting…"; "daemon not running" with its reason; "0/3 running · 0 waiting", "none running" and "empty"; and `emulator-5554 Pixel_8 leased claude#4242 demo 0:09 59m` plus `1 codex#4343 checkout Pixel_Tablet 0:05`, nothing truncated. Quit is drawn as a real button in each.
- ✅ With the daemon down, `berth-bar` started no `daemon run` and created no socket. The status item title was not read: Accessibility was not available in the agent's shell.

After the spec amendment, the two ❌ lines above no longer apply. `window-id` is proven on an on-screen window. The popover capture and the status item title are checked by a human.

Feedback round 1, runtime re-check by agent on the rebased branch:
- ✅ `swift build` passes. `swift test` passes: 14 tests in 3 suites, plus XCTest.
- ✅ The 4 PNGs again show readable text and full rows, and Quit is a real button. The new "Launch at login" checkbox from #9 renders unchecked above Quit.
- ✅ No plist was written under `~/Library/LaunchAgents`.

## Feedback

### Round 1 — 2026-10-16

**Asked**: "feedback validate autopilot afk". This was the answer to the recommended fix: make the render tests pass on the new `main`.

**Triage**: defect. #9 added a `launchAtLogin` parameter to `StatusPanel`, and the render tests no longer compiled after the rebase. The acceptance criteria are unchanged.

**What changed** (route: implementer):
- `StatusPanelRenderTests` passes a `LaunchAtLogin` built on a temporary `LaunchAgent` with a fixed executable and an empty environment. It never touches `~/Library/LaunchAgents`.
- The shared helper `LaunchAgent.temporary(label:)` is new, in `Tests/BerthBarTests/Login/LaunchAgent+Temporary.swift`, and `LaunchAtLoginTests` uses it too. That change came from the autofix.

**Review**: clean. See `## Review`, "validation (after feedback round 1)".

**Verify**: ✅. See `## Verification`, feedback round 1.
