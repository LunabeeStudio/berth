---
issue: BERTH-2
phase: validated
type: feature
wiki: [[broker]], [[android-backend]], [[cli]]
note:
created: 2026-10-26
---

## Context / Decisions

Ticket: when another adb client kills the adb server (Android Studio, or Gradle's ddmlib, which berth's guard cannot see), every emulator turns offline for a while. Agents then think the device is broken, release it and claim again, which forces a reset that also waits on adb. On 2026-10-26 the server was killed 34 times between 15:46:46 and 15:59:30 local (`$TMPDIR/adb.501.log`: `adb server killed by remote request`). The daemon should notice adb server restarts, log them to `daemon.log`, and surface an "adb unstable" state in `berth status`, `berth-bar` and the claim output, so agents wait instead of churning devices.

Decisions (unattended grill, 2026-10-26):
- **Detection = the adb server pid changes.** On each reap tick (every 5 s), the daemon reads the pid of the process listening on the adb server port (`ANDROID_ADB_SERVER_PORT`, default 5037), for example with `lsof -nP -t -iTCP:<port> -sTCP:LISTEN`. A restart is a pid different from the last pid seen. A sample with no server listening is skipped, so "killed, then started again" counts once. The first pid after daemon start is the baseline, not a restart. Only when the pool has Android entries. (autopilot assumption: the pid catches every restart between two ticks, also those by other clients; "every serial offline at once" is only a symptom)
- **berth never kills or restarts the adb server to detect this.** It only observes.
- **Log**: one `daemon.log` line per restart, `adb server restarted (pid <old> → <new>)`.
- **"adb unstable" lasts 60 s after the last restart seen.** One fixed constant, no config key (YAGNI). (autopilot assumption)
- **Snapshot**: `StateSnapshot` gains an optional `adbRestartedAt: Date?` (last restart seen), decoded when present, so old clients and old daemons keep working. Clients decide "unstable" by comparing it with the snapshot time. (autopilot assumption)
- **Notice text**, the same everywhere: `adb unstable: server restarted <n> s ago; devices reconnect on their own, keep your lease`. (autopilot assumption)
- **`berth status` and `berth top`** show the notice as a line under the header while adb is unstable, nothing otherwise.
- **berth-bar**: the panel shows the notice under the summary line while adb is unstable. The menu bar symbol turns to `exclamationmark.triangle` meanwhile. (autopilot assumption: a human glancing at the menu bar sees why devices go offline)
- **Claim output**: when a claim arrives while adb is unstable, or a restart is seen while it waits, the daemon sends the notice to that waiter as an `.ok` event. `berth claim` and `berth run` print it on stderr as `berth: <notice>`; stdout still carries only the serial. Old clients ignore `.ok` during a claim, so no new event case is needed. (autopilot assumption)
- **Out of scope**: `docs/AGENTS.md` and the skill are not changed here (BERTH-3 edits them; the notice text already says what to do). The reap rule that stops a slot missing from `adb devices` for 3 ticks is not changed. Both can be follow-up tickets. (autopilot assumption)
- **Tests**: the pid sampling sits behind a small injected function so the broker side (restart detection, log, snapshot field, claim notice) is unit tested without a real adb server. Status line rendering and the panel are covered by the existing render tests (`StatusPanelRender`, `MenuBarLabelTests`).
- Wiki: [[broker]] (adb restart watch, notice to waiters), [[android-backend]] (how the server pid is read), [[cli]] (status line).

## Acceptance criteria

- When the pid of the adb server changes between two reap ticks, `daemon.log` gets one line `adb server restarted (pid <old> → <new>)`.
- The first adb server pid seen after the daemon starts is not logged as a restart, and a tick where no adb server listens is not counted as a restart on its own.
- For 60 s after the last restart, the state snapshot carries `adbRestartedAt`, and `berth status` shows a line `adb unstable: server restarted <n> s ago; devices reconnect on their own, keep your lease`. After 60 s without a restart, the line is gone.
- The berth-bar panel shows the same notice under the summary line while adb is unstable, and the menu bar symbol is `exclamationmark.triangle` meanwhile; otherwise both look as today.
- `berth claim` started while adb is unstable, or waiting when a restart is seen, prints `berth: adb unstable: …` on stderr; stdout still prints only the serial.
- A snapshot without `adbRestartedAt` (older daemon) decodes and shows no notice.
- berth never runs `adb kill-server` or restarts the adb server itself.
- `swift test` passes, with unit tests for restart detection, the snapshot field, the status line and the claim notice.

## Implementation

One brick (autopilot, 2026-10-26), plus two autofix rounds.

**BerthCore**
- `Format/AdbInstability.swift`: `window` (60 s), `isUnstable(restartedAt:now:)` (unstable while 0 ≤ age < 60 s), and `notice(restartedAt:now:)`, which builds the shared text.
- `Model.swift`: `StateSnapshot.adbRestartedAt: Date?`, decoded with `decodeIfPresent`.
- `Format/StateSnapshot+Summary.swift`: `adbNotice(now:)`.
- `Client.swift`: `DaemonClient.claim` takes an `onNotice` callback, called for `.ok` events.

**BerthDaemon**
- `Adb/AdbRestartDetector.swift`: pure struct. It keeps the first pid as baseline, skips nil samples, and reports a restart when the pid changes.
- `Adb/AdbServerPid.swift`: `lsof -nP -t -iTCP:<port> -sTCP:LISTEN`, with the port from `ANDROID_ADB_SERVER_PORT` (default 5037). It only observes the server.
- `Broker.swift`: takes an injected, non-optional sampler (default `{ nil }`) and samples only when the pool has Android entries. `reap()` runs `watchAdbServer()` first. On a restart it logs one line, stamps `adbRestartedAt` and sends the `.ok` notice to every Android waiter. A claim made while adb is unstable gets the notice too. `snapshot()` stamps `adbRestartedAt` only while adb is unstable.
- `Daemon.swift`: passes `AdbServerPid.sample` to the broker.

**berth CLI**
- `ClaimFlow` prints `berth: <notice>` on stderr. `berth run` uses the same flow.
- `StatusRenderer` shows the notice line under the header, for `status` and `top`, using its live `now`.

**BerthBar**
- `StatusPanel` shows the notice under the summary line, in orange, using `model.now`.
- `MenuBarLabel.symbolName(for:now:)` returns `exclamationmark.triangle` while adb is unstable.
- `StatusItemController.refresh()` tracks `model.now` so the symbol expires on time. It writes the image and title only when they change.

**Tests**
- Detector cases: baseline, change, nil skipped, same pid.
- The `isUnstable` window boundary.
- An old snapshot without `adbRestartedAt` decodes.
- Status line shown and hidden.
- Menu bar symbol, including expiry with the live clock.
- Panel render with the notice.
- Broker notice on claim while unstable, on a restart while waiting, and none when stable.
- An iOS-only pool never samples adb.

**Wiki**
- [[broker]]: new "adb restart watch" section.
- [[android-backend]]: how the adb server pid is read.
- [[cli]]: claim and status rows.
- Index line for broker.

## Review

### validation (autopilot) — 2026-10-26
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓
- Round 1, 6 minor findings:
  - [correctness] The notice age was computed from the snapshot's `generatedAt`, so it froze between snapshots and lingered up to 5 s past the window.
  - [correctness] The adb sample ran after `live`/`current` were taken. Because of actor reentrancy, those values could be stale.
  - [structure] The "Android pool only" rule sat in the composition root, untested.
  - [elegance] The notice string was built just to test the window.
  - [style] A doc comment restated the code.
  - [style] Two `let`s had no explicit type.
  - All 6 fixed by autofix.
- Round 2, 1 minor finding: [correctness] the status item was redrawn every 1 s tick. Fixed: image and title are written only when they change.
- Round 3: clean.

## Verification

- ✅ `swift build` and the full `swift test` are green.
- ✅ Own daemon run: `BERTH_HOME=/tmp/bb2`, pool with only a nonexistent AVD, device lock taken. Over 2 reap ticks it logged only the start (baseline, no restart line). `berth status` showed no notice, and `--json` had no `adbRestartedAt`. The daemon was killed by pid.
- ✅ Panel render with the notice, from the `StatusPanelRender` test: orange line "adb unstable: server restarted 12 s ago; devices reconnect on their own, keep your lease" under the summary.
- The unstable path (a real adb server restart) is proven by unit tests only. Restarting the shared adb server would have dropped other agents' emulators.

## Feedback
