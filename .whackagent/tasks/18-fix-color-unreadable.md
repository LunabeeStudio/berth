---
issue: 18
phase:
wiki: [[architecture]]
note:
created: 2026-10-19
---

## Context / Decisions

User report: a screenshot of the `berth-bar` panel opened over a dark terminal, in light mode, on macOS 27. The panel text (headings, emulator row, "empty", "Launch at login") sits on a medium-gray background and is hard to read; the green "free" state label is the weakest.

Cause, from the code: `StatusPanel` draws no background of its own, so the `NSPopover` glass material shows through and takes the tint of whatever window is behind it. Dark text on a darkened glass gives low contrast. The state label also uses plain system colors as text color (`SlotState.color`: yellow, green, cyan, purple, gray), and yellow, green and cyan text are under 2.5:1 on a light background even when nothing dark is behind.

- **Opaque panel background.** `StatusPanel` fills its whole area with the system window background color (`windowBackgroundColor`, light in light mode, dark in dark mode). The text then keeps the same contrast whatever is behind the popover. The popover keeps its own frame and arrow; nothing else in `StatusItemController` changes. (autopilot assumption)
- **State shown as a colored dot plus plain text.** In the emulator row, the state cell becomes a small filled circle in the state color, followed by the state name in the primary text color. The colors in `SlotState.color` stay as they are; they now only color the dot. Rejected alternative: darker custom shades of each color for light mode, which needs a hand-tuned palette for two appearances to fix the same problem. (autopilot assumption)
- **Nothing else changes.** Panel width (620), columns, fonts, texts and the `.secondary` style of minor texts stay. The CLI TUI colors are out of scope. (autopilot assumption)
- **Where it lives.** Existing files of the `BerthBar` `Panel/` feature only: `StatusPanel.swift` (background), `EmulatorRow.swift` (state cell). No new folder. If the state cell grows beyond a few lines, it may become its own small view in `Panel/`. (autopilot assumption)
- **Tests.** `StatusPanelRenderTests` already renders the panel offscreen in the light appearance. Add the dark appearance (`darkAqua`) for the live-busy state, and assert that the rendered image is fully opaque (every pixel alpha = 1) in both appearances. Before the fix the background is transparent, so this check fails; after it, it passes. PNGs are still written when `BERTH_PANEL_PNG_DIR` is set.
- **Runtime proof.** The real popover only exists once a human clicks the menu bar item (see `CLAUDE.md#Desktop proofs`). The agent proves the panel by the render tests and by looking at the light and dark PNGs. Checking the real popover over a dark window stays with the user.
- **Docs.** Wiki `architecture` page: one line under key decisions saying the panel draws an opaque background because the glass popover is unreadable over dark windows.

## Acceptance criteria

- `swift build` and `swift test` pass.
- The panel rendered offscreen by `StatusPanelRenderTests` is fully opaque (every pixel has alpha 1) in the light appearance and in the dark appearance.
- In the rendered PNGs (`BERTH_PANEL_PNG_DIR`), the light appearance shows dark text on a light background and the dark appearance shows light text on a dark background.
- In the emulator row, each state shows a filled dot in its state color, followed by the state name in the primary text color.
- Panel width stays 620 points, and the columns, texts and fonts are otherwise unchanged.
- With the menu bar in light mode and a dark window behind the popover, opening the panel shows every text readable on a light, uniform background.
- The same check in dark mode shows every text readable on a dark, uniform background.

## Implementation

## Review

## Verification

## Feedback
