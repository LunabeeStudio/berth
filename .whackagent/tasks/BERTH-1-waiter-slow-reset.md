---
issue: BERTH-1
phase: validated
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

One brick (autopilot, 2026-10-26), reworked in four autofix rounds.
- `Sources/BerthDaemon/Broker.swift`:
  - New constant `slowTransition: TimeInterval = 60`.
  - A booting or resetting slot is slow once it has been in that state for 60 s or more, unless it is a replacement slot.
  - The bound is per slot, not per waiter. A slow slot has at most one replacement booting at a time (a new one may boot after the previous fails or is granted), and a replacement slot is not slow while the slot it replaces is still in transition.
  - One broker-private map, `replacedSlowSlots`: slow serial → `ReplacementMark(slowSince, replacement, replacementSince)`. A slow slot counts as replaced only while it still has `slowSince` and the replacement is still booting with `replacementSince`. A replacement slot is exempt from slowness only while a mark names it. So a failed or granted replacement frees the slow slot for a new replacement. `pruneReplacementMarks()` drops dead marks on each pass.
  - Order per waiter in `provisionForWaiters`:
    1. Take a matching upcoming slot that is not slow.
    2. If the pool has room: when a matching slow slot without a replacement exists, boot one and mark both slots. Otherwise, when no matching upcoming slot exists at all, boot as before.
    3. Otherwise wait on any matching slow slot. Nothing is evicted.
    4. Otherwise the existing pending-stop and eviction paths run.
  - Helpers: `takeUpcoming(for:where:)` takes a matching upcoming slot. `boot` now returns the new serial (`String?`).
  - No change to `Slot`, the protocol or the config.
- `Tests/BerthDaemonTests/BrokerSlowSlotTests.swift` (new) uses the injected clock and FakeBackend `holdResets`/`holdLaunches`, and asserts on `h.slots()` and on grants. It covers:
  - under 60 s, the waiter keeps waiting;
  - at 60 s, a replacement boot and a grant;
  - no room: no eviction and no stop, and the waiter is granted the slot after its reset;
  - a boot granted to another waiter still lets the slow slot be replaced;
  - a waiter boots only once past a slow slot;
  - each of two slow slots gets exactly one replacement;
  - a slow reset and a slow claim-time boot get one replacement each;
  - a failed replacement boot lets the next pass boot another;
  - a new waiter gets a boot once the replacement went to another waiter.

## Review

### validation (autopilot) — 2026-10-26
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- Round 1: 1 major and 6 minor findings.
  - Major [correctness]: a waiter booted again every 60 s once its own boot turned slow.
  - Minor [correctness]: test assertions raced the async boot Task, and the two-waiter test ran at the pool limits.
  - Minor [structure]: the take-upcoming block was duplicated.
  - Minor [style]: untyped locals and `grant!`.
  - All fixed by autofix with a per-waiter flag.
- Round 2: 1 major and 2 minor findings.
  - Major [correctness]: the per-waiter flag broke when FIFO handed that waiter's boot to an earlier waiter.
  - Autofix moved the bound to slots (replacement marks).
- Round 3, orchestrator: a take-order gap. An already-replaced slow slot was taken first, so a second slow slot never got its replacement. Autofix made slow slots a last resort.
- Round 4 (final): previous findings fixed. The verifier agrees that "one replacement per slow slot" meets criterion 5. Autofix cap reached, so 2 findings stay open:
  - 🟡 minor [correctness] `Broker.swift:54`: when the replacement boot fails, the slow slot keeps its "replaced" mark. The waiter then waits on that slow slot until its reset ends, even with room in the pool. Recommendation: fix now. Store the replacement serial with the mark, and drop the mark when that replacement is gone or no longer booting.
  - 🟡 minor [style] `BrokerSlowSlotTests.swift:140`: the test name says "one slow slot" but the test sets up two (the reset and the held claim-time boot). Recommendation: fix now. Rename it to `a slow reset and a slow claim-time boot get one replacement each`.

### validation — 2026-10-27
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- Round 1: both open findings confirmed. The mark finding was raised to 🟠 major [correctness]: a replaced mark outlived its replacement when the replacement boot failed, and also when the replacement was granted and a new waiter came while the slot was still slow, so that waiter was parked on the slow slot with pool room (criterion 2). Autofix stored the replacement in the mark and counted the mark only while the replacement is still booting. 2 tests were added, and both fail on the old code. The test was renamed.
- Round 2: 2 minor findings. [elegance] two maps held the same fact: merged into one `ReplacementMark` map. [style] the multi-line `guard` form was fixed.
- Round 3: 2 minor findings. [style] the doc comment still said "the replacement is never slow": reworded. [style] the private struct was declared before an internal one: moved.
- Round 4 (user-approved, wording only): [style] a slow slot has at most one replacement booting at a time, not one in total. Comment and task file were reworded.
- Verdict: clean.

## Verification

- ✅ `swift build` and the full `swift test` are green, 3 runs in a row.
- ✅ CLI smoke test: `berth --version` and `berth status --help` run.
- ✅ `swift test --filter BrokerSlowSlot`: 10 tests, green after the last round. The full `swift test` is green after the logic change.
- ✅ Real emulator, final code: an own daemon (`BERTH_HOME=/tmp/bt1`) on a throwaway AVD with pool room, after `kill -STOP` on the emulator relaunched by a reset.
  - The first claim waits, then a replacement boots 62 s after the reset began, and the claim gets it.
  - A second claim boots another emulator at once (8 s) instead of waiting on the slow slot.
  - After `kill -CONT`, the slow slot ends its reset and becomes `free`.
  - A fast reset (about 5 s) is waited on and reused, with no new boot.
  - The adb server was not touched.

## Feedback
