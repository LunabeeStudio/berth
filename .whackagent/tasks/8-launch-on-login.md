---
issue: 8
phase: validated
wiki: [[architecture]], [[cli]]
note:
created: 2026-10-16
---

## Context / Decisions

User request: "Launch on login (toggable from tray menu)". The tray menu is the `berth-bar` panel (the popover opened from the menu bar item).

Prior art: `SMAppService.mainApp` / `SMAppService.agent(plistName:)` (ServiceManagement, macOS 13+) is the native login-item API, but it needs a `.app` bundle (the agent plist must sit in `Contents/Library/LaunchAgents`). `berth-bar` is a bare SwiftPM executable with no bundle (decided in #1), so it does not fit. A per-user launchd agent in `~/Library/LaunchAgents` works for a bare executable, and `berth daemon install` already does exactly that for the daemon (`com.berth.daemon`). No third-party library needed. (autopilot assumption)

- **Mechanism.** A launchd agent plist `~/Library/LaunchAgents/com.berth.bar.plist`. The toggle is on exactly when that file exists: no separate preference is stored. (autopilot assumption)
- **Plist content.** `Label` `com.berth.bar`; `ProgramArguments` = the absolute path of the running `berth-bar` executable, symlinks resolved (same way `berth daemon install` resolves its own path); `RunAtLoad` true; `LimitLoadToSessionType` `Aqua` and `ProcessType` `Interactive` (GUI app, graphical login only). **No `KeepAlive`**: Quit must stay quit until the next login. (autopilot assumption)
- **`BERTH_HOME`.** launchd starts the agent with a minimal environment, so a custom `BERTH_HOME` would be lost and the bar would watch the wrong socket. When `BERTH_HOME` is set at the moment the user turns the toggle on, the plist carries it in `EnvironmentVariables`; unset → no `EnvironmentVariables` key. (autopilot assumption)
- **Turning on** writes the plist (creating `~/Library/LaunchAgents` if missing). It does **not** call `launchctl bootstrap`: with `RunAtLoad` that would start a second `berth-bar` right away. launchd picks the file up at next login. (autopilot assumption)
- **Turning off** deletes the plist. It does **not** call `launchctl bootout`: when the running app was itself started by launchd at login, bootout would kill it. (autopilot assumption)
- **Toggle never lies.** After each on/off attempt the app re-reads whether the plist exists and shows that. A failed write leaves the toggle off; no alert (YAGNI). (autopilot assumption)
- **Moved binary.** If the user moves or rebuilds `berth-bar` elsewhere, the plist keeps the old path. Turning the toggle off and on rewrites it. Auto-repair at launch is out of scope (YAGNI). (autopilot assumption)
- **UI.** A "Launch at login" checkbox (`Toggle`, checkbox style) in the panel, just above the Quit button, visible in every state (connecting, live, disconnected). (autopilot assumption)
- **Where it lives — shared code, no duplication.**
  - `LaunchAgent` (today a private helper inside `Sources/berth/Commands/Daemon.swift`: label, plist URL, `gui/<uid>` domain) moves to `BerthCore` as one small public type, parameterised by label and by the LaunchAgents directory (injectable so tests write to a temp dir, never to the real `~/Library/LaunchAgents`). It owns the plist URL, "is installed", write a plist dictionary, and remove. `berth daemon install` / `uninstall` use it with label `com.berth.daemon`; their behavior and plist content do not change. (autopilot assumption)
  - `BerthBar` gets a new feature folder `Login/` for the launch-at-login logic (builds the bar's plist dictionary, reads and sets the enabled state). The panel only binds to it. (autopilot assumption)
- **Tests.** Swift Testing on the pure logic, in a temp directory: the bar's plist dictionary (path, `RunAtLoad`, no `KeepAlive`, `BERTH_HOME` passthrough on and off); `LaunchAgent` write → installed, remove → not installed, written file is a valid XML plist. SwiftUI views are not unit tested.
- **Runtime proof.** Clicking the menu bar item needs the mouse, which agent runs must not touch (see #5). The agent proves the plist logic by tests and by inspecting a generated file (`plutil -lint`); the real login and the click on the checkbox stay with the user.
- **Docs.** README "Menu bar" section mentions the checkbox and the plist path; wiki `architecture` page lists `Login/` and the shared `LaunchAgent`.

## Acceptance criteria

- `swift build` and `swift test` pass.
- The `berth-bar` panel shows a "Launch at login" checkbox just above Quit, whatever the daemon state.
- With no `~/Library/LaunchAgents/com.berth.bar.plist`, the checkbox is off.
- Turning the checkbox on writes `~/Library/LaunchAgents/com.berth.bar.plist`: valid plist (`plutil -lint` OK), `Label` `com.berth.bar`, `ProgramArguments` = the absolute path of the running `berth-bar` with symlinks resolved, `RunAtLoad` true, no `KeepAlive` key.
- When `BERTH_HOME` is set in the app's environment, the written plist has `EnvironmentVariables` with that `BERTH_HOME`; when unset, the plist has no `EnvironmentVariables`.
- Turning the checkbox off deletes that plist, and the running app keeps running.
- Reopening the panel, or relaunching the app, shows the checkbox matching whether the plist exists.
- With the checkbox on, after logging out and back in, the berth item is in the menu bar without launching it by hand.
- With the checkbox on, Quit exits the app and launchd does not restart it before the next login.
- `berth daemon install` and `berth daemon uninstall` behave as before: same path `~/Library/LaunchAgents/com.berth.daemon.plist`, same plist content.
- README documents the checkbox.

## Implementation

Brick 1 — shared launchd helper in `BerthCore`, no behavior change:
- `Sources/BerthCore/Launchd/LaunchAgent.swift`: `LaunchAgent(label:directory:)` — plist URL, `isInstalled`, `domain` (`gui/<uid>`), `write(_:)` (XML, creates dir), `remove()` (no-op if absent), `currentExecutablePath()` (symlinks resolved).
- `Sources/berth/Commands/Extensions/LaunchAgentExtension.swift`: `LaunchAgent.daemon` (`com.berth.daemon`). `Daemon.swift` install/uninstall use it; plist path, content and launchctl calls unchanged.
- `Sources/BerthCore/Paths.swift`: `Paths.homeVariable` (`BERTH_HOME`), used everywhere the name appears.
- `Tests/BerthCoreTests/Launchd/LaunchAgentTests.swift` (temp dir only).

Brick 2 — `berth-bar` checkbox:
- `Sources/BerthBar/Login/LaunchAtLogin.swift`: `@Observable @MainActor`; settable `isEnabled` writes/removes `com.berth.bar.plist` then re-reads the file (always notifies, so the checkbox never lies); `refresh()`; pure `plist(label:executable:environment:)`.
- `Panel/StatusPanel.swift`: `Toggle("Launch at login")`, checkbox style, above Quit, every state. `MenuBar/StatusItemController.swift` calls `refresh()` before showing the popover; `App/BerthBarDelegate.swift` wires it.
- `Tests/BerthBarTests/Login/LaunchAtLoginTests.swift`: plist keys (no `KeepAlive`), `BERTH_HOME` set/absent/empty, enable/disable round trip, refresh after outside change.
- README "Menu bar": checkbox, plist path, toggle off/on after moving the binary.

Build: `swift build` green. Tests: `swift test` green (35 + 14 + 10 tests across runs).

## Review

### validation (autopilot) — 2026-10-16

Round 1: 12 minor findings — correctness: checkbox could stay checked after a failed write; panel showed stale state when the plist changed outside the app. Structure: `BERTH_HOME` literal repeated; daemon label sat in `BerthCore`. Style: member order, explicit types. Elegance: `set(_:)` + hand-built `Binding`.
Autofix: settable `isEnabled` with `withMutation` + `@Bindable`; `refresh()` before popover show; `Paths.homeVariable`; `LaunchAgent.daemon` moved to `berth` target extension; order + explicit types fixed.
Round 2: all 12 fixed, no new finding. Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean.

## Verification

- ✅ `swift build` + `swift test` pass.
- ✅ Builder output written to a temp dir: `plutil -lint` OK; `plutil -p` shows `Label com.berth.bar`, `ProgramArguments`, `RunAtLoad 1`, `LimitLoadToSessionType Aqua`, `ProcessType Interactive`, `EnvironmentVariables {BERTH_HOME}` when set, no `KeepAlive`.
- ✅ Tests: write/remove/isInstalled round trip, refresh after outside change, `BERTH_HOME` absent → no `EnvironmentVariables`.
- ✅ `berth daemon --help` still lists run, stop, install, uninstall.
- ✅ `BERTH_HOME=<tmp> .build/debug/berth-bar` starts and stays up (2 s, killed).
- Not run by agent (needs mouse or a real login): clicking the checkbox, logout/login launch, Quit not restarted by launchd, real `berth daemon install`/`uninstall`.

## Feedback
