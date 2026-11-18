---
issue: BERTH-18
phase: review
type: bug
wiki: [architecture, broker]
note: Incident 2026-11-18 09:41 UTC, ~/Library/Logs/berth/daemon.log. Daemon 907 died, daemons 43074 then 48890 adopted nothing; emulator-5554..5560 kept running untracked.
created: 2026-11-18
---

## Context / Decisions

What happened on 2026-11-18 (from `daemon.log`, times UTC):

- 09:35–09:40 daemon 907 booted `emulator-5554`, `-5556`, `-5558` (leased to three Claude sessions) and `emulator-5560` (booting).
- 09:41:00 daemon 907 exited with `Error: NIOFcntlFailedError()`. The only `throw` path that ends `Daemon.run` at that point is the accept loop in `Server.run`: `for try await connection in connections` ends on the first error of the server channel. On Darwin, NIO throws `NIOFcntlFailedError` when it sets an accepted socket non-blocking after the peer already closed it, which is likely when several clients connect and give up at once. One bad accept ended the whole daemon.
- Waiting clients auto-spawned a new daemon. 43074 started at 09:41:00, logged `listening` at 09:41:01, and was gone before 09:41:05 with no log line (it most likely hit the same accept error under the same burst of clients). 48890 started at 09:41:05 and is the current daemon.
- Neither 43074 nor 48890 logged `adopted from previous daemon`. `Broker.restore()` adopts a saved slot only when its serial is in `backend.listing()?.live`, and treats a failed listing (`nil`) as an empty one: nothing adopted, and the empty slot list is written over `state.json`. So 48890 loaded the empty state 43074 had written. Why 43074's listing missed the four emulators is not proven (no log line): the listing is `nil` as soon as either the Android or the iOS listing fails, and the pool holds both platforms. The fix does not depend on the cause.
- Result: four emulators running, not tracked (`berth status` showed `1/5 running`), one session lost its lease and claimed a second emulator.

Grilled unattended by `/wa-autopilot` on 2026-11-18. Decisions tagged `(autopilot assumption)` are for the user to confirm or correct.

- A failed accept is logged (`accept failed: <error>`) and the daemon keeps serving, with its in-memory state. Preferred way: a handler in the server channel pipeline drops per-connection accept errors before they reach the async accept sequence. As a safety net, if the accept sequence still ends with an error, the server binds the socket again and keeps going, with a short delay between attempts so a socket that can never be bound does not spin. (autopilot assumption)
- `restore()` never takes an unknown device list for an empty one. It retries the listing a few times (3 attempts, 2 s apart). When the listing is still unknown, it adopts every saved slot whose emulator process is still alive (`isProcessAlive(pid)`), and keeps a saved slot without a pid; the reap tick then drops slots that vanished, as it already does. (autopilot assumption)
- `restore()` logs every saved slot it does not adopt, with the reason (`<serial>: not adopted (<reason>)`), so the next incident can be read from `daemon.log`. (autopilot assumption)
- Out of scope: cleaning up the four emulators that are running now (the user decides, by hand), and listing unmanaged emulators (BERTH-17). Out of scope too: the auto-spawn burst itself; the lock file already lets only one daemon run at a time. (autopilot assumption)

## Acceptance criteria

- An error on one incoming connection (for example `NIOFcntlFailedError` on accept) is written to `daemon.log` and does not stop the daemon: the next `berth status` is answered by the same daemon pid, with the same slots and leases.
- A test fires such an accept error through the server pipeline and checks that the server keeps accepting connections.
- When the device listing fails at daemon start, saved slots whose emulator process is alive are adopted, and `state.json` is not overwritten with an empty list.
- When the listing fails at start and a saved slot's process is dead, that slot is not adopted, and `daemon.log` says so with its serial.
- When the listing works, adoption behaves as today: a saved slot is adopted when its serial is listed, and dropped with a log line otherwise.
- Broker tests cover a failed listing at restore (alive pid adopted, dead pid dropped, state file kept), using the fake backend; `swift build` and `swift test` pass.

## Implementation

- `Sources/BerthDaemon/AcceptErrorFilter.swift`: server-channel handler added through `serverChannelInitializer` (in `Server.bind`, shared by the daemon and the test). It swallows only `NIOFcntlFailedError`, the one accept error NIO forwards to the sequence (IOErrors are consumed by NIO's `AcceptBackoffHandler`, which the filter must not starve of them). It logs `accept failed: <error>` at most once per second, with the count of errors held back since the last line.
- `Server.run` loops: when the accept sequence ends (error or closed socket) it cancels live connections, logs `server stopped: ...` and binds again after 1 s, same broker. Only cancellation ends it.
- `Broker.restore`: listing retried 3 times (`listingRetryDelay`, default 2 s, injected as `.zero` in `Harness`). Listing known: adopt listed slots as before. Listing unknown: adopt slots whose pid is alive or without pid. Every dropped slot logs `<serial>: not adopted (<reason>)`.
- Style pass: `Server.bind` moved above `run`; explicit types on the server and iterator declarations.
- Tests: `AcceptErrorFilterTests` (real `Server.bind` on a temp unix socket: error fired on the server pipeline, then a client connection is still accepted; test deps now include NIO, `@testable import NIOPosix` since `NIOFcntlFailedError.init` is internal), `BrokerRestoreTests`; `FakeBackend` gained `failListings()` and `kill(pid:)`.

## Review

### validation (autopilot) — 2026-11-18

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict after 3 rounds: clean.

Round 1, 7 findings, all fixed by autofix:
- 🟠 [correctness] The filter also swallowed IOErrors (ECONNABORTED, EMFILE…) ahead of NIO's `AcceptBackoffHandler`. That turned off the 1 s accept backoff, so EMFILE would spin and flood the log. Fixed: only `NIOFcntlFailedError` is swallowed.
- [correctness] The filter test used its own EmbeddedChannel, not the real server pipeline. Fixed: `Server.bind` is shared, and the test binds a real unix socket.
- [correctness] When the accept sequence ended normally, the rebind waited forever on a long-lived `watch` connection. Fixed: `group.cancelAll()` after the accept loop.
- [correctness] Bind failures were logged as `accept failed:`. Fixed: `server stopped: <error>, listening again`.
- [style] Member order in `AcceptErrorFilter`; explicit types in `Broker` and `FakeBackend`. Fixed.
- Also changed, not a finding: `accept failed` is logged at most once per second, with a count. A burst used to write 10854 lines.

Round 2, 2 findings (🟡 style: `Server.bind` member order, explicit types on the server and iterator declarations). Fixed.
Round 3: clean. Withdrawn: 0. Disputed: 0. Not covered by a test: the rebind path itself.

## Verification

- `swift build` green, no warnings; `swift test` all suites pass.
- Runtime (own daemon, `BERTH_HOME=/tmp/b18`): 32 threads x 400 connect-then-reset clients reproduced the incident error: one rate-limited `accept failed: NIOFcntlFailedError()` line in the daemon log (10854 unlimited lines before the rate limit). Same daemon pid stayed alive, `berth status` answered. Daemon stopped with `kill <pid>`.
- Restore proven by unit tests only (no runtime state.json written, to keep real emulators untouched).

## Feedback

### Round 1 — 2026-11-18

Asked: "rebase on main" (BERTH-17 landed in #63).
Triage: adjustment. Routed `inline`: a mechanical rebase of the ticket range onto `origin/main`.
Changed (inline, no convention pass; the verifier should judge these hunks harder):
- `Broker.restore()`: keeps this ticket's `listingWithRetry` + `notAdoptedReason`. Drops this ticket's `devices = listing?.devices ?? []`, because main now sets `devices = await publishedDevices(listing)` after adoption. With an unknown listing, `publishedDevices` keeps the previous list (empty at start).
- `Broker`: `publishedDevices` (main) and `listingWithRetry` + `notAdoptedReason` (this ticket) placed side by side.
- `FakeBackend`: both sides' state and helpers kept. `listing()` returns nil when `failListing`, otherwise includes `emulators`. `isProcessAlive` reads `deadPids`.
Warnings: 0 new. Build ✅, tests ✅ (63 + 151 + 76 + 79→83 after main's kill tests).
Review: deferred to `/wa-validate`. Verify: no runtime re-run. Only the merge of both sides changed, and the unit tests cover restore and the unmanaged listing.

