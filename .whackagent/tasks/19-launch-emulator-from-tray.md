---
issue: 19
phase:
wiki: [[architecture]], [[broker]], [[android-backend]], [[cli]]
note:
created: 2026-10-19
---

## Context / Decisions

User request: "Add launch emulator from tray menu". The tray menu is the `berth-bar` panel. Three readings were possible. The user chose this one (2026-10-19): from the panel, start an emulator **for the user**, with a window, leased to them so no agent ever gets it. The panel also offers to **release it without killing it**.

User answers (2026-10-19):
- **Lifetime.** No TTL, and quitting `berth-bar` does not end it. Berth stops owning the emulator only in two cases. When the user clicks Release, berth forgets it and the emulator keeps running as the user's own. When the user closes the emulator window, berth sees it vanish. Berth never kills it behind the user's back.
- **Scope.** Android only: the menu lists the pool AVDs. Each launch boots a **new** windowed instance (same `-read-only` + clean snapshot boot as agents get: fast, writes lost on exit). It counts toward `maxRunning` and `maxInstances`. When the pool is full, it waits in the queue like any claim.

Decisions settled by autopilot from the code (each one tagged):

- **One concept, one name: `windowed`.** `ClaimRequest` gets an optional `windowed: Bool?` (nil = false, so old clients still decode). `Slot` gets `windowed: Bool`, persisted in `state.json`. A `state.json` written before this change decodes with `windowed = false`. (autopilot assumption)
- **Booting.** `DeviceBackend.launch` gets a `windowed` parameter. `AndroidBackend` drops `-no-window` when it is true and keeps every other flag. `IOSSimulatorBackend` never receives `windowed: true`. (autopilot assumption)
- **Claim validation.** A windowed claim must name a model, and the model must be an Android pool entry. Otherwise it fails at once: "windowed launch needs an Android pool AVD". (autopilot assumption)
- **Scheduling.** A windowed waiter never takes a free or upcoming headless slot: it always gets a slot booted windowed for it. A headless waiter never takes a windowed slot. Windowed waiters keep their FIFO place and may evict an idle headless slot exactly like any waiter, because they count in the limits. (autopilot assumption)
- **No reclaim.** The reap loop never reclaims a windowed lease for a dead owner or an expired TTL. The lease owner is `berth-bar`, whose pid may be gone, and `expiresAt` is `Date.distantFuture`. A windowed slot that vanishes from `adb devices` because the user closed the window is stopped and removed as today. (autopilot assumption)
- **Release = forget.** `release <serial|lease>` on a windowed slot does not reset or stop it. The broker drops the slot without any shutdown, keeps the serial out of port picking (`externalSerials`), and answers `ok("released <serial>; it keeps running and berth no longer manages it")`. From then on it is one of the user's own emulators, which berth never touches. `release` on a headless slot is unchanged: reset by restart. (autopilot assumption)
- **Protected from bulk stops.** `stop-all` and eviction never stop a windowed slot. An explicit `berth stop <serial>` (or `x` in `berth top`) still stops it, because it names that device. (autopilot assumption)
- **Self-update.** The idle check (`isIdle`, used by the daemon re-exec) ignores leased windowed slots. Otherwise the user's emulator would block auto-update forever. The re-exec keeps the pid and re-adopts the slot from `state.json`. (autopilot assumption)
- **Panel.** The panel gets a "Launch emulator" menu listing the Android pool AVDs from the snapshot (`snapshot.pool`). It is visible only while the daemon is live. Choosing an AVD sends a windowed claim with that model and label `you`, then acknowledges the grant and closes the connection. While it waits, the claim shows in Queue like any other. A refused claim shows its message as one caption line under the menu, until the next launch attempt. `berth-bar` is no longer read-only toward the daemon. It still never auto-spawns it. (autopilot assumption)
- **Release in the panel.** For a windowed slot, the emulator row shows a "Release" button in the remaining-time column. The column shows no time for it, since it never expires. Clicking it sends `release <serial>`. Agent-leased rows are unchanged and have no button. (autopilot assumption)
- **CLI.** `berth status` and `berth top` show `—` in the remaining column for a windowed lease. No new CLI flag: launching windowed is a panel feature (YAGNI). (autopilot assumption)
- **Where it lives.** BerthCore: `Protocol.swift` (`ClaimRequest.windowed`) and `Model.swift` (`Slot.windowed`). BerthDaemon: `Broker.swift`, `Backends/DeviceBackend.swift`, `Backends/AndroidBackend.swift`, `Backends/IOSSimulatorBackend.swift`, `Backends/DeviceRouter.swift` (launch signature). BerthBar: a new feature folder `Launch/` holds the daemon actions (windowed claim + ack, release) and the launch error state. `Panel/` only binds to it (menu, Release button). berth: `TUI/StatusRenderer.swift` and the `top` remaining column. (autopilot assumption)
- **Tests.** Broker tests use `FakeBackend`, which records the `windowed` flag of each launch. The cases are: a windowed claim boots a windowed slot even when a free headless one exists; a headless claim never gets a windowed slot; a dead owner or a past `expiresAt` does not reclaim a windowed lease; release forgets a windowed slot with no shutdown and no reset; stop-all and eviction skip it; the idle check ignores it; a windowed claim for an iOS model or with no model fails. `Slot` decodes old JSON that has no `windowed` key. `AndroidBackend` launch arguments contain `-no-window` only when headless (pure argument builder, no emulator run). `StatusPanelRenderTests` renders a windowed slot. Desktop proofs follow `CLAUDE.md#Desktop proofs`.
- **Runtime proof.** The agent may boot a real windowed emulator only on a pool AVD no human uses, with a short `BERTH_HOME` (project notes). It may never click the panel. The real Launch menu and Release button need a click: human check.
- **Docs.** README "Menu bar" section: the Launch menu and Release button. Wiki `broker` page: windowed slots. Wiki `android-backend`: the windowed boot flag. Wiki `architecture`: `berth-bar` is no longer read-only, plus the `Launch/` folder. Wiki `cli`: `—` remaining for windowed.

## Acceptance criteria

- `swift build` and `swift test` pass.
- With the daemon live, the `berth-bar` panel shows a "Launch emulator" menu listing every Android AVD of the pool, and no iOS simulator. With the daemon down or connecting, the menu is not shown.
- Choosing an AVD boots a new instance of it with a visible emulator window, even when a free headless instance of the same AVD is running.
- That emulator appears in the panel and in `berth status` as leased, label `you`, and no `berth claim` from an agent is ever granted it.
- When `maxRunning` is reached, the launch waits in the Queue section and boots once room frees up, exactly like an agent claim.
- The windowed lease is never reclaimed: not after the default TTL, not after `berth-bar` quits, and not by the reap loop.
- In the panel, the windowed emulator row shows a "Release" button instead of a remaining time. Agent-leased rows show no button.
- Release (button, or `berth release <serial>`) removes the emulator from berth: it disappears from the panel and from `berth status`. The emulator process and its window keep running, and berth never stops or reuses it afterwards.
- `berth release` on an agent-leased emulator still resets it as before.
- Closing the emulator window removes it from berth within the usual vanish delay.
- `berth stop-all` leaves the windowed emulator running and leased. `berth stop <serial>` stops it.
- `berth status` and `berth top` show `—` as remaining time for the windowed lease.
- A windowed claim for an iOS simulator, or with no model, is refused with a clear message, and the panel shows that message.
- A `state.json` written before this change still loads. A daemon restart re-adopts a running windowed emulator as leased and windowed.
- README documents the Launch menu and Release.

## Implementation

## Review

## Verification

## Feedback
