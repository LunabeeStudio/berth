# Broker

`actor Broker` (BerthDaemon/Broker.swift) = all scheduling state. Injected `now` + `ownerAlive` closures → deterministic tests (`Tests/BerthDaemonTests`, FakeBackend).

## Slot lifecycle
`booting → free → leased → resetting → free … → stopping → removed`
- Slot keyed by serial; `generation` int guards async completions (stale task for removed/recreated slot ignored).
- Async work (boot, reset, shutdown) runs in unstructured Task, re-enters actor via `bootFinished` / `resetFinished` / `removeSlot`.

## Scheduling (`schedule()`, after every mutation)
1. `grantFreeSlots` — FIFO; each waiter takes oldest free matching slot (`model` nil = any).
2. `provisionForWaiters` — leftover waiters each claim one upcoming slot (booting/resetting), else boot new (if `slots.count < maxRunning` and model under `maxInstances`), else count pending stop, else **evict** oldest free slot (free here = nobody wants it).
3. `publishPositions` — `.queued(position)` only on change.
Waiter for busy AVD never blocks waiter fitting free one.

## Leases
- `Lease{id 8 hex, owner, label, grantedAt, expiresAt, acknowledged}`.
- Owner = `Owner{pid, startTime, name}`; start time compare defeats PID reuse.
- Reclaimed (→ reset) when: owner dead, TTL expired, client disconnected before `ack`.
- `release`/`renew`/`stop` accept serial or lease id.

## Reap (every 5 s)
- `liveSerials` from adb; free/leased slot missing 3 ticks (or pid dead + missing) → stop.
- Dead owners / expired leases → reset; dead-owner waiters → failure.
- Free > `idleShutdownSeconds` → stop.

## Failure handling
- Boot fail ×3 for model → model "broken" 10 min, its waiters failed (any-waiters failed only if all models broken).
- Reset fail → stop slot (next boot equally clean, see [[android-backend]]).
- `stopAll` fails all waiters + stops every slot.