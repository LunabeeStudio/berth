# Broker

`actor Broker` (BerthDaemon/Broker.swift) = all scheduling state. Injected `now` + `ownerAlive` closures → deterministic tests (`Tests/BerthDaemonTests`, FakeBackend).

## Slot lifecycle
`booting → free → leased → resetting → free … → stopping → removed`
- Slot keyed by serial; `generation` int guards async completions (stale task for removed/recreated slot ignored).
- Async work (boot, reset, shutdown) runs in unstructured Task, re-enters actor via `bootFinished` / `resetFinished` / `removeSlot`.

## Scheduling (`schedule()`, after every mutation)
1. `grantFreeSlots` — FIFO; each waiter takes oldest free matching slot (`model` nil = any model of request platform; `ClaimRequest.resolvedPlatform`, nil = android for old clients).
2. `provisionForWaiters` — leftover waiters each claim one upcoming slot (booting/resetting), else boot new (if `slots.count < maxRunning` and model under `maxInstances`), else count pending stop, else **evict** oldest free slot (free here = nobody wants it).
3. `publishPositions` — `.queued(position)` only on change.
Waiter for busy AVD never blocks waiter fitting free one. Android waiter never takes iOS slot, and reverse.

## Claim validation
Model must be pool entry of request platform, else "not in the pool". Pool has no entry of platform → fail. Backend `unavailableReason(model:)` (iOS devices not created) → fail at once; any-platform claim fails only when every model unavailable; `candidateModels` skips unavailable.

## Leases
- `Lease{id 8 hex, owner, label, grantedAt, expiresAt, acknowledged}`.
- Owner = `Owner{pid, startTime, name}`; start time compare defeats PID reuse.
- Reclaimed (→ reset) when: owner dead, TTL expired, client disconnected before `ack`.
- `release`/`renew`/`stop` accept serial or lease id.

## Windowed slots (#19)
Two notions. `Slot.windowed` = boot mode (window, kept for slot life). `Lease.manual` = lease granted to windowed claim from `berth-bar` (user's own). Both persisted, old `state.json` → false. `Slot.isManuallyLeased` = leased + manual.
- Claim `windowed: true`: needs model, Android pool entry, else failure "windowed launch needs an Android pool AVD".
- Matching: windowed request → windowed slot only (reuses free windowed of its model). Headless request → prefers headless, may take free windowed, never upcoming (booting/resetting) windowed. Windowed waiter of model has priority on free windowed slot.
- In limits (`maxRunning`, `maxInstances`). Windowed waiter w/o instance room → takes own model's in-flight stop, else stops oldest free slot of own model, else waits — never eats other model's pending stop.
- Manual lease: `expiresAt = .distantFuture`; reap never reclaims (dead owner, expiry); `renew` refused; unacked on disconnect → kept; `stopAll` skips; `isIdle` ignores (self-update not blocked). Explicit `stop` stops it.
- `release` manual → slot `free` at once, **no reset**: same emulator, window + state kept, any claim takes it as is.
- Agent lease on windowed slot = normal lease (TTL, owner reclaim); release/reclaim → reset by restart, relaunched windowed (`reset(…, windowed:)`).
- Free windowed = normal free slot: idle stop, eviction, `stopAll`. Launcher left mid-boot → slot just ends free. Vanish → stopped as usual.

## Reap (every 5 s)
- `liveSerials` from adb; free/leased slot missing 3 ticks (or pid dead + missing) → stop.
- Dead owners / expired leases → reset; dead-owner waiters → failure.
- Free > `idleShutdownSeconds` → stop.

## Failure handling
- Boot fail ×3 for model → model "broken" 10 min, its waiters failed (any-waiters of same platform failed only if all its models broken or unavailable). Messages name device kind (AVD / simulator).
- **Orphan race**: stop (`stop-all`, eviction) while boot/reset in flight → task later brings device up for dead slot. `discardOrphan` installs fresh-generation `.stopping` slot + `startShutdown` → serial held until shut down, never one newer slot owns.
- Reset fail → stop slot (next boot equally clean, see [[android-backend]]).
- `stopAll` fails all waiters + stops every slot except leased windowed.