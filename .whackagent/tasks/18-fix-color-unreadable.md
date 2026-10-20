---
issue: 18
phase: validated
wiki:
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
- **Docs.** No wiki line: a local color fix is not an architecture decision.

## Acceptance criteria

- `swift build` and `swift test` pass.
- The panel rendered offscreen by `StatusPanelRenderTests` is fully opaque (every pixel has alpha 1) in the light appearance and in the dark appearance.
- In the rendered PNGs (`BERTH_PANEL_PNG_DIR`), the light appearance shows dark text on a light background and the dark appearance shows light text on a dark background.
- In the emulator row, each state shows a filled dot in its state color, followed by the state name in the primary text color.
- Panel width stays 620 points, and the columns, texts and fonts are otherwise unchanged.
- With the menu bar in light mode and a dark window behind the popover, opening the panel shows every text readable on a light, uniform background.
- The same check in dark mode shows every text readable on a dark, uniform background.

## Implementation

Brick 1 — opaque panel + state dot:
- `Sources/BerthBar/Panel/StatusPanel.swift`: `.background(Color(nsColor: .windowBackgroundColor))` after `.frame(width: 620)`, so the padding is covered too.
- `Sources/BerthBar/Panel/EmulatorRow.swift`: state cell = 8 pt `Circle` filled with `slot.state.color`, then the state name in primary text color; column width still 70. `SlotState+Color.swift` unchanged.
- `Tests/BerthBarTests/Panel/StatusPanelRenderTests.swift`: `render` takes an `appearance` (default `.aqua`); `expectOpaque` counts pixels with alpha ≠ 1; parameterized test `panel is opaque in every appearance` over light (`live-busy`) and dark (`live-busy-dark`), size + opacity checked. It replaces the former light live-busy render test.

Build: `swift build` green. Tests: `swift test` green, 0 failures.

## Review

### Round validation (autopilot) — 2026-10-19

Round 1: 3 minor findings, all in the render test — structure: unused `appearance` parameter on `writePNG`; elegance: light opaque test overwrote the `live-busy` PNG and skipped the size check; elegance: nested loops with a mutable counter in `expectOpaque`.
Autofix: parameter removed; one parameterized test for both appearances; `reduce` + `count(where:)`.
Round 2: 3 fixed; 1 new minor (structure): the old light live-busy test duplicated the parameterized `.aqua` case. Autofix: old test dropped, light argument named `live-busy`.
Round 3: fixed, no new finding. Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean.

### Round validation — 2026-10-20

Scope: ticket range (`160c2dc^`), code + task file; feedback round 1 hunks flagged inline.
Round 1: code clean; 3 minor findings in the task file — style: round 1 feedback block not in the sibling bold-label format; structure: a line named a machine-local path of another repo; style: review heading not `### Round validation (autopilot)`.
Fix (main thread, task file only): block rewritten with bold labels, path line dropped, heading renamed.
Round 2: 3 fixed, no new finding. Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean. Wiki: nothing to sync (local fix).

## Verification

- ✅ `swift build` + `swift test` pass.
- ✅ Opacity assertion failed before the fix (transparent background), passes after, light and dark.
- ✅ Render PNGs (`BERTH_PANEL_PNG_DIR`): light = light opaque background, dark readable text, cyan dot + "leased" in primary color; dark = near-black opaque background, white text, cyan dot visible.
- ✅ Width 620 check passes; columns, texts and fonts unchanged.
- ✅ Own `.build/debug/berth-bar` (`BERTH_HOME=/tmp/bb18`) stayed up 2 s, stopped by pid; `desk-state` identical before and after (no input sent, frontmost app unchanged).
- Not run by agent (needs a click on the menu bar item): real popover over a dark window, light and dark mode.

## Feedback

### Round 1 — 2026-10-20

**Asked**: "A simple color change should not fill .whackagent/wiki/architecture.md"

**Triage**: adjustment, plus a rule: a local fix gets no wiki line. The acceptance criteria are unchanged. The rule is recorded in the whackagent plugin, not in this project.

**What changed** (route: inline):
- `.whackagent/wiki/architecture.md` is back to `main`: no line for #18.
- Task file: `wiki:` is empty, and the Docs decision says no wiki line.

**Review**: see `## Review`, round validation 2026-10-20: clean.

**Verify**: docs only, no code changed. `swift build` and `swift test` green. The earlier runtime proof still holds.
