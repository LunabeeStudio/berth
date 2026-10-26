# CLAUDE.md

<!-- board-contract: 2.4 -->
## Board

Issues and pull requests in this repository follow [BOARD.md](BOARD.md), whatever tool or work loop you use. Before you work on an issue or open a pull request, read BOARD.md and follow it: claim the ticket first, never move a card yourself, one PR per ticket, a human decides every merge.
<!-- /board-contract -->

## Desktop proofs

A proof of `berth-bar` must never take the user's mouse, keyboard or frontmost app.

- Never: CGEvent or System Events clicks or keystrokes, `cliclick`, `osascript … activate`, `screencapture` without `-l`, anything addressed to another pid or to a window position.
- No Accessibility action (`AXPress` or other) on `berth-bar`: pressing its status item opens the popover, which activates the app and takes focus. AX attribute reads addressed by pid (status item title) are allowed.
- Launch your own `.build/debug/berth-bar` in the background with a short `BERTH_HOME` (for example `/tmp/bb5`), record its pid, stop it with `kill <pid>`. Never by name (`pkill`, `killall`): the user may run their own.
- Take `desk-state` before and after each step: `xcrun swift tools/desktop/desk.swift desk-state` (frontmost app and cursor, one JSON line). The frontmost app must not change.
- Window by pid: `xcrun swift tools/desktop/desk.swift window-id <pid>`; capture: `xcrun swift tools/desktop/desk.swift capture <pid> <out.png>` (`screencapture -l`). They address the pid's own on-screen windows: for `berth-bar`, the popover once a human has opened it. On macOS 27 the status item is drawn by `MenuBarAgent`, another pid, so it is never captured; on older macOS `window-id` may return it. Prove its label with an AX title read addressed by pid, or ask a human.
- Panel content is proven by the render tests, not on screen: `BERTH_PANEL_PNG_DIR=<dir> swift test --filter StatusPanelRender`, then look at the PNGs.
- A human checks what needs real input: opening the popover with a click, and the Quit button.
