---
issue: 19
phase: validated
wiki: [[architecture]], [[broker]], [[android-backend]], [[cli]]
note:
created: 2026-10-19
---

## Context / Decisions

User request: "Add launch emulator from tray menu". The tray menu is the `berth-bar` panel. Three readings were possible. The user chose this one (2026-10-19): from the panel, start an emulator **for the user**, with a window, leased to them so no agent ever gets it. The panel also offers to **release it without killing it**.

User answers (2026-10-19):
- **Lifetime.** No TTL, and quitting `berth-bar` does not end it. Berth stops owning the emulator only in two cases. When the user clicks Release, berth forgets it and the emulator keeps running as the user's own. When the user closes the emulator window, berth sees it vanish. Berth never kills it behind the user's back.
- **Scope.** Android only: the menu lists the pool AVDs. Each launch boots a **new** windowed instance (same `-read-only` + clean snapshot boot as agents get: fast, writes lost on exit). It counts toward `maxRunning` and `maxInstances`. When the pool is full, it waits in the queue like any claim.

Feedback round 1 (2026-10-19), user: "when I release the emulator I launched, I expect it to appears as \"free\", not to disappear". User answer to the follow-up: after release, any claim may take it, as is, with no reset.

- **Two separate notions.** `Slot.windowed` = the emulator has a window (boot mode); it stays true for the slot's whole life. `Lease.manual` = the lease was granted to a windowed claim from the menu bar (the user's own lease), persisted, old JSON decodes `false`. The "never reclaimed", "renew refused", "skipped by stop-all", "ignored by the idle check", Release button and `—` rules all key on `Lease.manual`, not on `Slot.windowed`.
- **Release = back to free, no reset.** `release` of a manual lease sets the slot `free` (lease cleared, `stateSince` = now) without reset or restart: the emulator keeps running with its window and its current state. Reply: `ok("released <serial>; it stays running, free for the next claim")`. `release` of any other lease is unchanged: reset by restart.
- **Free windowed slot = normal pool slot.** Any claim may take it as is. A windowed claim (Launch) takes a free windowed slot of its model instead of booting a new one. A headless claim may take a free windowed slot too, but a windowed waiter of that model has priority on it. A headless claim never takes an upcoming (booting/resetting) windowed slot. A windowed claim never takes a headless slot.
- **Agent on a windowed slot.** An agent lease on a windowed slot is a normal lease (TTL, owner reclaim). Its release or reclaim resets the slot by restart, and the slot comes back windowed (`reset` relaunches with the slot's `windowed`).
- **Idle stop and eviction apply** to a free windowed slot like to any free slot (15 min idle → stopped, window closes). `stop-all` stops it unless a manual lease holds it.
- **No orphan stop.** A windowed slot booted for a launcher that left becomes a normal free windowed slot (replaces the earlier "stopped once ready" rule).
- The earlier "Release = forget" decision below is superseded.

Decisions settled by autopilot from the code (each one tagged):

- **One concept, one name: `windowed`.** `ClaimRequest` gets an optional `windowed: Bool?` (nil = false, so old clients still decode). `Slot` gets `windowed: Bool`, persisted in `state.json`. A `state.json` written before this change decodes with `windowed = false`. (autopilot assumption)
- **Booting.** `DeviceBackend.launch` gets a `windowed` parameter. `AndroidBackend` drops `-no-window` when it is true and keeps every other flag. `IOSSimulatorBackend` never receives `windowed: true`. (autopilot assumption)
- **Claim validation.** A windowed claim must name a model, and the model must be an Android pool entry. Otherwise it fails at once: "windowed launch needs an Android pool AVD". (autopilot assumption)
- **Scheduling.** A windowed waiter never takes a free or upcoming headless slot: it always gets a slot booted windowed for it. A headless waiter never takes a windowed slot. Windowed waiters keep their FIFO place and may evict an idle headless slot exactly like any waiter, because they count in the limits. (autopilot assumption)
- **No reclaim.** The reap loop never reclaims a windowed lease for a dead owner or an expired TTL. The lease owner is `berth-bar`, whose pid may be gone, and `expiresAt` is `Date.distantFuture`. A windowed slot that vanishes from `adb devices` because the user closed the window is stopped and removed as today. (autopilot assumption)
- ~~**Release = forget.**~~ (superseded by feedback round 1) `release <serial|lease>` on a windowed slot does not reset or stop it. The broker drops the slot without any shutdown, keeps the serial out of port picking (`externalSerials`), and answers `ok("released <serial>; it keeps running and berth no longer manages it")`. From then on it is one of the user's own emulators, which berth never touches. `release` on a headless slot is unchanged: reset by restart. (autopilot assumption)
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
- The manual lease (from the Launch menu) is never reclaimed: not after the default TTL, not after `berth-bar` quits, and not by the reap loop.
- In the panel, the windowed emulator row shows a "Release" button instead of a remaining time. Agent-leased rows show no button.
- Release (button, or `berth release <serial>`) of the manual lease turns the emulator `free` in the panel and in `berth status`, with no restart: the process and its window keep running.
- After that release, the next agent claim for that AVD (or any Android claim) gets that same emulator as is, without reset. Its release then resets it by restart, and it comes back with a window.
- Launch emulator on an AVD that has a free windowed instance reuses that instance instead of booting a new one.
- A free windowed emulator is stopped by idle shutdown and eviction like any free emulator.
- `berth release` on an agent-leased emulator still resets it as before.
- Closing the emulator window removes it from berth within the usual vanish delay.
- `berth stop-all` leaves an emulator held by a manual lease running and leased. `berth stop <serial>` stops it.
- `berth status` and `berth top` show `—` as remaining time for a manual lease; an agent lease on a windowed emulator shows its time.
- A windowed claim for an iOS simulator, or with no model, is refused with a clear message, and the panel shows that message.
- A `state.json` written before this change still loads. A daemon restart re-adopts a running windowed emulator as leased and windowed.
- README documents the Launch menu and Release.

## Implementation

Brick 1 — daemon side of windowed claims:
- `BerthCore/Protocol.swift`: `ClaimRequest.windowed: Bool?` + `isWindowed`. `BerthCore/Model.swift`: `Slot.windowed`, custom `init(from:)` (missing key → false).
- `BerthDaemon/Backends/DeviceBackend.swift`, `DeviceRouter.swift`, `IOSSimulatorBackend.swift`: `launch(serial:model:windowed:)`. `AndroidBackend.swift`: internal pure `launchArguments(model:port:windowed:snapshot:)`, `-no-window` only when headless.
- `BerthDaemon/Broker.swift`: windowed claim validation; `matches` requires same `windowed`; boot windowed for windowed waiters; windowed waiter without instance room takes its own model's in-flight stop or stops the oldest free slot of its model (`freeInstance`), never another model's pending stop; lease `expiresAt = .distantFuture`; reap skips windowed for dead owner/expiry; `renew` refused; `release` forgets (no shutdown/reset, serial into `externalSerials`); `stopAll` skips leased windowed; windowed slot ready with no windowed waiter → stopped; unacked windowed lease kept on disconnect; `isIdle` ignores leased windowed.

Brick 2 — panel + CLI:
- `BerthCore/Client.swift`: `DaemonClient.claim(_:autoSpawn:timeout:onQueued:) -> Grant` (claim → queued → granted → ack loop), shared by `berth/Berth.swift` `ClaimFlow` (behavior unchanged) and the bar.
- `BerthBar/Launch/EmulatorLauncher.swift` (new feature folder): `@Observable @MainActor`; `launch(model:)` (windowed claim, label `you`, owner berth-bar, `autoSpawn: false`), `release(serial:)`, `error`. Wired in `App/BerthBarDelegate.swift`, `MenuBar/StatusItemController.swift`.
- `BerthBar/Panel/StatusPanel.swift`: "Launch emulator" menu (Android pool entries, live only) + error caption. `Panel/EmulatorRow.swift`: "Release" button in remaining column for windowed slots (owner column 95, remaining 60).
- `berth/TUI/StatusRenderer.swift`: remaining `—` for windowed (status + top).
- README "Menu bar": Launch menu + Release.
- Tests: `BrokerWindowedTests` (boot windowed with free headless present, headless never gets windowed, no reclaim, renew refused, release forgets, port skip, stop-all/eviction, no-room eviction, no over-eviction, orphan stop, idle check, refused claims, vanish), `SlotDecodingTests`, `AndroidLaunchArgumentsTests`, `EmulatorLauncherTests`, `StatusRendererTests`, `StatusPanelRenderTests` (`live-windowed`).

Build: `swift build` green, no warnings. Tests: `swift test` green (37 + 69 + 28 + 17).

## Review

### validation (autopilot) — 2026-10-19

Round 1: 11 findings. Major — correctness: windowed waiter stuck when free headless slots of its model fill `maxInstances` (until idle shutdown); structure: claim loop duplicated from `ClaimFlow` and already diverging. Minor — correctness: free windowed orphans unevictable; row 598 pt > 596 pt; `renew` lied about expiry. Style/elegance/structure: member order, stale `isIdle` comment, implicit type, needless `public`, condition hidden in `flatMap`, repeated `.frame`.
Autofix: own-model stop for no-room windowed waiter; shared `DaemonClient.claim`; orphan stop + filter dropped; owner 95 pt; `renew` refused; style fixes.
Round 2: 11 fixed; 1 new minor (correctness): no-room windowed waiter consumed another model's pending stop → extra eviction. Autofix: `freeInstance` with per-model stop accounting + test.
Round 3: fixed; 1 new minor (style): force-unwrap in test. Autofix: `#require`.
Round 4: fixed, no new finding. Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean.

### validation — 2026-10-19 (user green light, `/wa-validate 19`)

Scope: whole ticket range (incl. feedback round 1, not reviewed before).
Round 1: 9 minor, no major. Correctness: no test for eviction of a free windowed slot. Structure: manual-lease predicate repeated 8× in 3 targets; `EmulatorLauncher` hard-wired to static `DaemonClient` (launch/release/error untestable). Elegance: ternary-to-nil in `StatusRenderer`. Style: implicit types (`Broker`, `Harness`, `FakeBackend`), test names still saying "windowed" for manual-lease rules, Lease test in Slot suite, `lines(windowed:)` toggling manual.
Autofix: `Slot.isManuallyLeased` used everywhere; `DaemonActions` protocol + `DaemonClientActions` injected into `EmulatorLauncher` (launch/release return discardable `Task`), `StubActions` tests for refused claim / failed release / cleared error; `remaining(_:)` with guard; eviction test; renames; `ModelDecodingTests`.
Round 2: 9 fixed, no new finding. Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean. Autofix touched code after the user's test: retest needed before ready.

## Verification

- ✅ `swift build` + `swift test` pass.
- ✅ Broker tests prove the windowed rules: windowed boot even with a free headless instance; no agent claim gets it; no reclaim by TTL/dead owner; release forgets without shutdown; stop-all skips it, `stop` stops it; queue + limits; refused iOS / no-model claims; old `state.json` decodes.
- ✅ Launch args: `-no-window` only when headless.
- ✅ Real AVD (own daemon, `BERTH_HOME=/tmp/bb19`, Pixel_9): headless `berth run`, `berth claim`, `berth release` (reset), `berth status`, `stop-all`, `daemon stop` behave as before after the claim loop moved.
- ✅ `StatusRendererTests`: `—` for windowed, time for agent leases.
- ✅ Render `live-windowed.png`: Release button in remaining column, Launch emulator menu, width 620, columns aligned.
- ✅ Own `berth-bar` launched 2 s, stopped by pid; `desk-state` unchanged (no input sent).
- Round 1 (feedback): build ✅, full `swift test` ✅; headless claim / run / release / stop-all on real Pixel_9 ✅; render: Release button on the manual-lease row only ✅.
- Validation autofix: build ✅, full `swift test` ✅ (37 + 77 + 29 + 19); render `live-windowed` unchanged ✅; headless `berth run` + `stop-all` on real Pixel_9 ✅.
- Not run by agent (window may take focus; needs clicks): real windowed boot, Launch menu entries, Release click, closing the window, daemon restart re-adopting a windowed emulator, `berth claim` timeout path.

## Feedback

### Round 1 — 2026-10-19

Asked (user): "when I release the emulator I launched, I expect it to appears as "free", not to disappear". Follow-up answer: after release, any claim may take it, as is, with no reset.
Triage: adjustment. Decisions and acceptance criteria updated (Feedback round 1 block in `## Context / Decisions`).
Route: implementer (fresh spawn; daemon + bar + CLI, several files).
Changed:
- `BerthCore/Model.swift`: `Lease.manual` (persisted, old JSON → false). Grant sets it from `request.isWindowed`.
- `BerthDaemon/Broker.swift`: no-reclaim, renew refusal, stop-all skip, idle-check exception and disconnect rule keyed on `lease.manual`. Release of a manual lease → slot `free`, no reset, no shutdown. `forget` and the orphan stop removed. `matches` / `freeSlot`: windowed request needs a windowed slot; headless request may take a free windowed slot (headless preferred), never an upcoming windowed one; windowed waiter has priority on a free windowed slot; Launch reuses a free windowed slot.
- Backends: `reset(…, windowed:)`; Android relaunches with the slot's window mode.
- `Panel/EmulatorRow.swift`, `TUI/StatusRenderer.swift`: Release button and `—` keyed on `lease.manual`.
- README "Menu bar": release returns it to the pool.
- Tests: broker cases for release → free, reuse as is, agent release → windowed reset, reclaim of agent lease on a windowed slot, Launch reuse, priority, no upcoming windowed for headless, idle stop, stop-all; Lease old-JSON decode; renderer + panel render keyed on manual.
Review: deferred to `/wa-validate` (`review.when: on_validation`). Wiki pages still describe "release = forget": `/wa-validate` re-syncs them.
Verify: build ✅, full `swift test` ✅ (37 + 76 + 29 + 17). Headless regression on own daemon (`berth run`, `claim`, `release` → reset → free, `stop-all`, `daemon stop`) ✅. Render `live-windowed`: Release on the manual row only ✅. Windowed boot and clicks not run by agent.

