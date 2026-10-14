# CLI

ArgumentParser `AsyncParsableCommand`s in `Sources/berth/`. Root `Berth` (Berth.swift).

| Command | Notes |
|---|---|
| `claim` | default Android; `--ios` any simulator, `--simulator X` that entry; `--avd` + `--ios`/`--simulator` = usage error (64); stdout = serial only (`S=$(berth claim)`); queue position → stderr; `--timeout` default 600 (0 = forever) → exit 2; `--owner-pid` override; `--json` |
| `run -- cmd` | owner = run process itself; `ANDROID_SERIAL` (Android) or `SIMULATOR_UDID` (iOS) set — wrap in `sh -c '…'` to use it in args; SIGINT/TERM/HUP forwarded; always release; exit with child status; `--timeout` default 0 |
| `release` / `renew` / `stop-all` | `autoSpawn: false` — never start daemon |
| `status [--json]` | `StatusRenderer`, colors only on tty; DEVICE column; UDID cut by `pad`, full in `--json` |
| `top` | TUI, need tty |
| `prepare <avd>` | Android only (rejects simulator entry); see [[android-backend]] |
| `daemon run/stop/install/uninstall` | install = launchd agent `com.berth.daemon` |

## Exit codes
0 ok · 1 error (`ClientError` printed `berth: …`) · 2 claim timeout.

## Owner detection
`ProcessInspector.detectOwner`: walk ancestors from ppid, skip shells/wrappers (`sh bash zsh … env timeout nohup sudo xargs rtk berth`). Claude Code → `claude` process (binary named by version under `…/claude/versions/X` → display name from path).

## TUI (`top`)
No deps: termios raw, alt screen, ANSI. Events merged → one `AsyncStream`: watch snapshots (reconnect loop 1 s), keys (own Thread, blocking `read`), 1 s tick, SIGWINCH. Keys ↑↓/jk select, `r` release, `x` stop, `q`/Esc/Ctrl-C quit.

## Agent guidance
`docs/AGENTS.md` = snippet for agent CLAUDE.md: prefer `berth run`, `--timeout 110` + retry on exit 2.