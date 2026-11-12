---
issue: BERTH-10
phase: validated
type: feature
wiki: [broker, cli]
note:
created: 2026-11-12
---

## Context / Decisions

Ticket: "Make every emulator have a different name by incrementing: Pixel 10 - 1, Pixel 10 - 2, etc…". Today two instances of the same AVD show the same `model` everywhere berth lists them, and only the serial tells them apart.

Grilled unattended by `/wa-autopilot` on 2026-11-12. Every decision below is an autopilot assumption for the user to confirm or correct.

- The name is shown on berth's own surfaces: the berth-bar panel row, `berth status` / the TUI, and the scrcpy mirror window title. (autopilot assumption)
- The emulator window and Android Studio are out of scope. The emulator has an `-id <name>` flag ("assign an id to this virtual device, separate from the avd name"), but nothing proves that Android Studio or the emulator window displays it. It can be a follow-up ticket once someone checks it on a device. (autopilot assumption)
- Name format: `<model> - <n>`, for example `Pixel_10 - 1`. `<model>` stays the AVD name berth already shows, not the AVD display name from `config.ini`: reading display names is a separate change and nothing needs it yet (YAGNI). (autopilot assumption)
- `<n>` is the lowest positive number that no other slot of the same model holds. It is assigned when the daemon creates the slot (claim boot or panel launch) and kept for the slot's whole life, including resets and lease changes. When the slot goes away, its number is free again, so a new slot reuses the gap: with `- 1` and `- 3` running, the next one is `- 2`. (autopilot assumption)
- The number lives on `Slot` (new persisted field, read with `decodeIfPresent` so an old `state.json` still loads). A slot restored without a number gets one on restore, with the same lowest-free rule, so nothing renders without a number. (autopilot assumption)
- The rule applies to every slot, iOS simulators included: one rule is simpler than a per-platform one, and simulators of the same type have the same problem. (autopilot assumption)
- The wire stays compatible: `berth claim` still prints the serial alone, and `--json` gains the new field without renaming any existing one. Agents keep addressing devices by serial. (autopilot assumption)

## Acceptance criteria

- Two emulators of the same AVD running at once show as `<model> - 1` and `<model> - 2` in `berth status`, in the TUI and in the berth-bar panel row.
- A single running emulator shows as `<model> - 1`.
- Numbers count per model: one `Pixel_9` and one `Pixel_10` running show as `Pixel_9 - 1` and `Pixel_10 - 1`.
- A slot keeps its number across a reset and across lease changes.
- When slot `- 1` is stopped while `- 2` runs, the next emulator of that model gets `- 1`.
- The scrcpy mirror window title contains the numbered name.
- A `state.json` written before this change still loads, and its slots get numbers.
- `berth claim` still prints only the serial; `swift build` and `swift test` pass.

## Implementation

- `Slot` gains a persisted optional `instance` number and a computed `displayName` (`<model> - <n>`, plain `model` when the number is nil, e.g. a snapshot from an older daemon). The field is read with `decodeIfPresent` (`Sources/BerthCore/Model.swift`).
- `Broker.lowestFreeInstance(of:)` gives the lowest positive number no other slot of the same model holds. It is used in `boot()`, `discardOrphan()` (which reuses the number of the stopping slot it replaces) and `restore()` (saved numbers kept first, then slots with a nil number in serial order). A stopping slot keeps its number until `removeSlot()` (`Sources/BerthDaemon/Broker.swift`).
- Display: `berth status` / TUI DEVICE column shows the name (column widened 16 → 18; `StatusRenderer.deviceCell` shortens the model and always keeps ` - n`); the berth-bar panel row shows it with middle truncation so the number stays visible; the scrcpy window title carries it through the mirror chain, whose `model` parameter is renamed `name` (`ScrcpyArguments`, `MirrorTarget`, `MirrorFlow`, `MirrorResolver`, `MirrorController`). Pool and platform matching still use `model`.
- Tests: new `BrokerInstanceTests` (5 cases), old-JSON case in `ModelDecodingTests`, title and column cases in the mirror and TUI tests; `Harness` takes an optional store, `FakeBackend.setLive(_:)`.
- Build: `swift build` green, full `swift test` green, 0 new warnings.

## Review

### validation (autopilot) — 2026-11-12

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict after 2 rounds: clean.

Round 1, 5 findings, all fixed by autofix:
- 🟠 [correctness] `EmulatorRow`: fixed 90 pt column with tail truncation cut the ` - n` suffix of long names (`Pixel_10_Pro - 2`, `iPhone 17 Pro - 1`). Fixed: `.truncationMode(.middle)` + render fixture with long names.
- 🟡 [correctness] `StatusRenderer`: names of 19+ characters lost the number in the DEVICE column. Fixed: `deviceCell` truncates the model part, keeps ` - n`, test added.
- 🟡 [elegance] `instance == 0` sentinel. Fixed: `instance: Int?`, `displayName` falls back to `model`.
- 🟡 [style] missing type annotations in `Broker` (3 declarations). Fixed.
- 🟡 [style] private helper before `@Test` methods in `BrokerInstanceTests`. Fixed.

Round 2: clean, no new finding. Withdrawn: 0. Disputed: 0.

## Verification

Runtime check by the implementer, own daemon (`BERTH_HOME=/tmp/b10`, pool `Pixel_9` ×2):
- ✅ Two background `berth claim --avd Pixel_9` → `emulator-5556  Pixel_9 - 1  leased` and `emulator-5558  Pixel_9 - 2  leased` in `berth status`.
- ✅ `berth claim` stdout is only the serial (`emulator-5556`, `emulator-5558`).
- ✅ `berth release emulator-5558` → resetting → free, still `Pixel_9 - 2`.
- ✅ After `berth stop-all`, the next claim gets `Pixel_9 - 1` again.
- Gap reuse while another slot of the model runs: unit test only (`the number of a stopped slot is reused by the next boot`) — no CLI stops a single slot.
- Panel row and scrcpy title: render tests (`live-busy.png`, `live-long-names.png`) and unit tests, not on screen.
- ✅ After autofix: one claim → `Pixel_9 - 1` in `berth status`, claim stdout serial only; build + full tests green.
