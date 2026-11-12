---
issue: BERTH-14
phase:
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
