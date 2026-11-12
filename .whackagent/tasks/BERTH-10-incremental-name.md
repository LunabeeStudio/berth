---
issue: BERTH-10
phase:
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
