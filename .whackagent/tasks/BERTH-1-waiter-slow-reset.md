---
issue: BERTH-1
phase:
type: bug
wiki: [[broker]]
note:
created: 2026-10-26
---

## Context / Decisions

Ticket: `provisionForWaiters` (`Sources/BerthDaemon/Broker.swift`) counts a booting or resetting slot as upcoming and does not boot a new emulator for the waiter it matches. A reset normally takes about 5 s, but nothing bounds how long a waiter keeps waiting on one. On 2026-10-26 a reset of emulator-5556 took 4m15 (adb kept going offline), and the waiter stayed queued while `maxRunning=5` and Pixel_9 `maxInstances=5` left 3 slots unused. The menu bar showed `1/2 +1` and the panel `2/5 running · 1 waiting`.

Decisions (unattended grill, 2026-10-26):
- **A booting or resetting slot is "slow" once it has been in that state for 60 s or more** (`now - stateSince >= 60`). One fixed constant on `Broker`, next to `brokenCooldown`, no config key (YAGNI). A snapshot boot takes 2 to 4 s and a reset 5 to 6 s ([[android-backend]]), so 60 s is ten times the usual time. A cold boot without the `berth-clean` snapshot can take longer: then a waiter may boot one extra emulator, still inside `maxRunning` and `maxInstances`, and the extra one idles out like any free slot. (autopilot assumption)
- **The rule applies to both booting and resetting slots**, as the ticket says, windowed or not. (autopilot assumption)
- **A waiter prefers a fresh upcoming slot, then a new boot, then a slow upcoming slot.** In `provisionForWaiters`, a waiter first takes a matching upcoming slot that is not slow (today's behavior). Otherwise, when the pool has room (`slots.count < maxRunning` and a candidate model under `maxInstances`), it boots a new emulator. Otherwise, when a matching slow slot exists, the waiter keeps waiting on it and nothing else happens: no eviction and no stop because of the slow slot. Only then the existing pending-stop and eviction paths run. (autopilot assumption: a slow slot must never make the broker evict another model's free emulator)
- **The slow slot is left alone.** It is not stopped or reset again. When its boot or reset ends, it becomes free and is granted to the next matching waiter or idles out as usual; a failure still stops it as today. (autopilot assumption)
- **No new timer.** `reap()` runs every 5 s and calls `schedule()`, so a waiter is re-provisioned within 5 s after its slot turns slow.
- **Tests** go in `Tests/BerthDaemonTests`, with `FakeBackend` and the injected `now` clock: a reset that never finishes is enough to reproduce the bug.
- Wiki: the [[broker]] page, *Scheduling* section, step 2 (`provisionForWaiters`) gains the slow-slot rule.

## Acceptance criteria

- A waiter whose only matching slot has been booting or resetting for less than 60 s keeps waiting on that slot; no new emulator is booted (unchanged behavior).
- Once that slot has been booting or resetting for 60 s or more, and the pool has room (`slots.count < maxRunning` and the model under `maxInstances`), the broker boots a new emulator for the waiter at the next scheduling pass (a reap tick at the latest).
- With no room in the pool, the waiter keeps waiting on the slow slot: no emulator is evicted or stopped because of it.
- The slow slot itself is not stopped; when its reset finishes it becomes free and serves the next waiter or idles out normally.
- Two waiters and one slow slot: each waiter gets at most one new boot, and the limits `maxRunning` and `maxInstances` still hold.
- Unit tests in `Tests/BerthDaemonTests` cover the criteria above, and `swift test` passes.

## Implementation

## Review

## Verification

## Feedback
