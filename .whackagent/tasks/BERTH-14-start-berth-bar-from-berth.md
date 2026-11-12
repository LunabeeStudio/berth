---
issue: BERTH-14
phase: validated
type: feature
wiki: [cli]
note:
created: 2026-11-12
---

## Context / Decisions

Idea, pasted 2026-11-12: "Improve the setup: make berth-bar startable as daemon/service from berth directly."

Today `berth daemon install` writes `~/Library/LaunchAgents/com.berth.daemon.plist` and bootstraps it. berth-bar starts by hand (`berth-bar &`), or through the panel's "Launch at login" checkbox, which writes `~/Library/LaunchAgents/com.berth.bar.plist` but never bootstraps it, so it only starts at the next login.

Decisions:

- New command group `berth bar` with two subcommands, `install` and `uninstall`, mirroring `berth daemon install|uninstall`. No `start` / `stop` subcommands: `berth-bar &` and the panel's Quit button already cover them (YAGNI).
- `berth bar install` writes the same `com.berth.bar` plist the checkbox writes, then runs `launchctl bootstrap gui/<uid>` on it, so berth-bar starts now and at every login. Because the file is the same, the panel checkbox shows ticked afterwards.
- `berth bar uninstall` runs `launchctl bootout` on the plist and removes it. The checkbox shows unticked afterwards. Like `berth daemon uninstall`, it succeeds when nothing is installed.
- The plist content is unchanged from today's checkbox plist: `ProgramArguments` = the berth-bar path, `RunAtLoad`, `LimitLoadToSessionType: Aqua`, `ProcessType: Interactive`, and `EnvironmentVariables.BERTH_HOME` when `BERTH_HOME` is set. No `KeepAlive`: Quit in the panel means quit until the next login or the next `berth bar install`. The checkbox and the CLI share one plist builder, moved from `Sources/BerthBar/Login/LaunchAtLogin.swift` into `BerthCore/Launchd`, next to `LaunchAgent`.
- The berth-bar path is the `berth-bar` file next to the resolved path of the running `berth` (`LaunchAgent.currentExecutablePath()`), the layout of every install (`~/.local/bin`, release archive, `.build/<config>`). Missing → exit 1 with `berth: berth-bar not found next to <berth path>`, and nothing written.
- A berth-bar already running is replaced. Only processes of the current user whose resolved executable path equals the plist's berth-bar path count; a berth-bar from another path (a `.build/debug` build used by desktop proofs, another install) is never touched. install sends each one SIGTERM, waits up to about 5 s for it to exit, then bootstraps. One still alive after the wait → exit 1 with a message naming its pid, and nothing bootstrapped (the plist stays written).
- A `com.berth.bar` job already loaded in launchd (the checkbox plist picked up at a past login, or an earlier `berth bar install`) makes a plain `launchctl bootstrap` fail. install first runs `launchctl bootout` on it, like `berth daemon install` does, ignoring the failure when nothing is loaded. That stops the berth-bar this job runs, whatever its path, because the job's plist is being replaced. The "another path is never touched" rule covers processes that job does not run. (autopilot assumption)
- berth-bar handles SIGTERM: a signal source calls `NSApp.terminate`, so the Quit cleanup runs (the scrcpy mirrors it opened are closed). This covers both the install replace and `launchctl bootout` on uninstall, which also sends SIGTERM.
- The command group lives in `Sources/berth/Commands/` beside `Daemon.swift`. It does not touch the daemon: installing the bar neither installs nor starts the broker.

## Acceptance criteria

- `berth bar install` with no berth-bar running writes `~/Library/LaunchAgents/com.berth.bar.plist`, bootstraps it, and a berth-bar process from the path next to `berth` is running afterwards. It prints `berth: installed <plist path>` on stderr and exits 0.
- The plist written by `berth bar install` is byte-for-byte the plist the panel checkbox writes for the same berth-bar path and `BERTH_HOME`, and the checkbox reads as ticked once it exists.
- With `BERTH_HOME` set, the plist carries `EnvironmentVariables.BERTH_HOME` with that value; without it, the plist has no `EnvironmentVariables`.
- `berth bar install` while a berth-bar from the same path runs: that process exits (its mirrors are closed), and a new berth-bar started by launchd runs in its place. Exactly one berth-bar from that path is running afterwards.
- `berth bar install` while a berth-bar from another path runs (for example `.build/debug/berth-bar`): that process keeps running with the same pid.
- A same-path berth-bar that is still alive after the wait makes `berth bar install` exit 1 with a message naming its pid, without bootstrapping.
- `berth bar install` with no `berth-bar` next to `berth` exits 1 with `berth: berth-bar not found next to <berth path>` and writes no plist.
- `berth bar uninstall` stops the launchd berth-bar (its mirrors are closed), removes the plist, prints `berth: uninstalled` and exits 0. Run again with nothing installed, it still exits 0.
- berth-bar receiving SIGTERM runs the same cleanup as Quit: the scrcpy mirrors it opened are stopped before it exits.
- `berth bar --help` lists `install` and `uninstall`; the README's command table lists `berth bar install|uninstall`, and its berth-bar section mentions it next to the "Launch at login" checkbox.

## Implementation

- Brick 1, shared plist builder: `Sources/BerthCore/Launchd/LaunchAgent+Bar.swift` holds `LaunchAgent.bar` (label `com.berth.bar`) and `writeBar(executable:environment:)`. The panel checkbox (`LaunchAtLogin`) and the CLI both write through it, so the two plists are the same bytes. The plist tests moved to `Tests/BerthCoreTests/Launchd/LaunchAgentTests.swift`.
- Brick 2, SIGTERM: `BerthBarDelegate` ignores SIGTERM and listens to it with a `DispatchSource` signal source on the main queue. The handler calls `NSApp.terminate(nil)`, so `applicationWillTerminate` runs `mirror.stopAll()`, the same cleanup as Quit.
- Brick 3, command: `Sources/berth/Commands/Bar.swift` adds `berth bar install|uninstall`, registered in `Berth.swift`. `Sources/BerthCore/Launchd/ExecutableReplacer.swift` finds the current user's processes by resolved executable path (`proc_listpids` + `proc_pidpath`, own pid skipped), sends them SIGTERM and waits up to 5 s. The pid lister, signal, liveness check and sleep are injected for tests (`ExecutableReplacerTests`). README: command table row, Install sentence, berth-bar section paragraph.
- Build and `swift test` green after every brick, no new warning.

## Verification

Runtime check by the agent (autopilot), against real launchd with an isolated label `com.berth.bar.proof-14`, a temporary LaunchAgents folder and a copy of the built berth-bar. The user's own `com.berth.bar` job, plist and process were never touched (plist compared byte for byte, pid alive at the end). The proof used a throwaway driver that replays `BarInstall` steps with the same building blocks; it was deleted.

- `berth bar --help` lists `install` and `uninstall`.
- `bar install` with no berth-bar next to berth prints `berth: berth-bar not found next to <berth path>`, exits 1, writes no plist.
- Bootstrap starts berth-bar from the path next to berth (launchd job running).
- A same-path berth-bar started by hand exits and exactly one berth-bar from that path runs afterwards, the launchd one.
- A `.build/debug/berth-bar` started by hand keeps its pid.
- Uninstall boots the job out (berth-bar exits on SIGTERM thanks to brick 2), removes the plist; run again with nothing installed, it succeeds.
- desk-state before and after each step: frontmost app unchanged, no click, no AX action.

After autofix (helpers moved, see `## Review`), the agent re-ran `berth bar --help`, the not-found path (user plist byte-identical, user pid alive) and the same-path replace / other-path untouched lookup; the isolated-label launchctl cycle was not re-run because `LaunchAgent.bootout()` / `bootstrap()` now live in the berth executable target, out of a test's reach, with the same launchctl arguments as before.

Not run by the agent: the real `berth bar install` / `uninstall` with the real label (the user's own berth-bar runs under it); the exact `BarInstall.run()` body; the bootstrap failure message; the survivor error against a real process (unit-tested with fakes); bootout of an already-loaded job then bootstrap; mirrors closing on SIGTERM (follows from `applicationWillTerminate`, not run).

## Review

### validation (autopilot)

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict clean after 1 autofix round.

- 🟠 `ExecutableReplacer.swift` duplicated the `proc_pidpath` code of `ProcessInspector.displayName` and extended `ProcessInspector` in another type's file: fixed. `executablePath(of:)` and `pids(running:)` now live in `ProcessInspector.swift`, and `displayName` uses `executablePath(of:)`.
- 🟡 `Bar.swift` copied the launchctl bootout and bootstrap blocks of `Daemon.swift`: fixed. `LaunchAgent.bootout()` and `bootstrap()` are in the berth target's `LaunchAgentExtension.swift` (they need `printError` and `ExitCode`), used by both commands with the same messages.
- 🟡 `ExecutableReplacer` injected closures were `public var`: fixed, now `private let`.
- 🟡 `configuration` without explicit type: withdrawn — every command file declares it untyped (Claim.swift, Daemon.swift, Guard.swift, MirrorCommand.swift, Prepare.swift, Run.swift, Status.swift, Update.swift).
- 🟡 `Bar.swift` holds three types and is not named after `BarCommand`: withdrawn — `Daemon.swift` and `Claim.swift` group a command with its subcommands the same way.

The verifier also checked that ignoring SIGTERM in berth-bar does not stop `Process.terminate()` from killing the scrcpy children (probe: a child launched with SIGTERM ignored was still killed), so the mirrors still close on Quit and on SIGTERM.
