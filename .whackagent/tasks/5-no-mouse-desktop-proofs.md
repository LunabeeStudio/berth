---
issue: 5
phase:
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

## Acceptance criteria

- `swift build` and `swift test` pass.
- `CLAUDE.md` has a `## Desktop proofs` section that states every rule listed under "Written rule" above, and the `.whackagent/config.md` project notes have one line that points to it.
- `xcrun swift tools/desktop/desk.swift desk-state` prints one JSON line with the frontmost app's pid and name and the cursor's x and y.
- With `berth-bar` launched in the background by the agent, `xcrun swift tools/desktop/desk.swift window-id <pid>` prints a window id and exits 0. For the pid of a process with no window, it prints nothing and exits 1.
- `xcrun swift tools/desktop/desk.swift capture <pid> <out.png>` writes a PNG that shows only the `berth-bar` status item (its symbol and label), even when another app is in front.
- Across launching `berth-bar`, `window-id`, `capture` and `kill <pid>`, the frontmost app reported by `desk-state` does not change.
- `swift test` runs a panel render test for each of the four states: connecting, disconnected, live empty, and live with a leased emulator plus a queued claim. Each produces a non-empty image 620 pt wide.
- With `BERTH_PANEL_PNG_DIR` set, the render tests write one PNG per state into that directory. The PNGs show readable text: "connecting…"; "daemon not running" with its reason; "none running" and "empty"; and the emulator row and queue row in full, not truncated. The Quit button is visible in each.
- `berth-bar` behaves as before: launched with the daemon down, it starts no daemon and its status item title is empty.

## Implementation

## Review

## Verification

## Feedback
