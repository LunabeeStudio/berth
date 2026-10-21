---
issue: 34
phase: validated
type: bug
wiki: [[claude-code]]
note:
created: 2026-10-21
---

## Context / Decisions

User report (2026-10-21): "my claude session in runmotion does not use berth". berth was installed in `~/.local/bin` (the `install.sh` default), but that directory was not on the PATH Claude Code inherited. The PreToolUse hook in `claude-plugin/hooks/hooks.json` runs `command -v berth >/dev/null 2>&1 || exit 0; berth guard`, so it exited 0 without a word. Agents then ran `adb devices` and `emulator -avd Pixel_9 …` unguarded. The skill's `berth claim` / `berth run` would also have failed with `command not found`.

Decisions (unattended grill, 2026-10-21):
- **Resolve berth in two places, PATH first.** Both hooks look for `berth` with `command -v berth`, then fall back to `$HOME/.local/bin/berth` when that file is executable. Only the install default is tried: no other directories and no config (YAGNI). (autopilot assumption)
- **PreToolUse guard stays fail open.** It runs `<resolved berth> guard`. When berth is not found, it exits 0 silently and never blocks. No warning on every Bash call: it would repeat on every command. (autopilot assumption)
- **New SessionStart hook in the same `hooks.json`, runs once per session:**
  - berth on PATH → nothing.
  - berth only at `$HOME/.local/bin/berth` → append `export PATH="$HOME/.local/bin:$PATH"` to `$CLAUDE_ENV_FILE` when that variable is set. The agent's Bash calls then find `berth`, so the guard's hints (`use berth run …`) and the skill commands work. No output. (autopilot assumption: goes past the ticket text, because a guard that tells the agent to run `berth` is useless when the agent cannot run it)
  - berth found nowhere → print one JSON line on stdout, `{"systemMessage": "berth not found on PATH or in ~/.local/bin: the device guard is off. Install: https://github.com/LunabeeStudio/berth#install"}`, exit 0. The user sees it once at session start. (autopilot assumption)
- **Commands stay inline in `hooks.json`**, POSIX `sh`, no script file. They must work under `/bin/sh` with a minimal PATH (`/usr/bin:/bin`). (autopilot assumption: two short lines do not need a script file)
- **No version bump.** The release flow (`docs/RELEASING.md`) bumps the plugin, marketplace and CLI versions together.
- **Docs.** In the README "Claude Code" section, replace "Without `berth` on PATH the hook does nothing." with the new behavior: fallback to `~/.local/bin`, PATH export for the session, warning when not found. Update the wiki page [[claude-code]] (guard hook section) the same way.
- **Tests.** In `Tests/berthTests/Plugin/`, read the hook commands from `hooks.json` and run each with `/bin/sh -c`, using a temporary `HOME`, `PATH=/usr/bin:/bin` and a fake `berth` script that records its arguments and exits with a chosen code.

## Acceptance criteria

- [x] With `PATH=/usr/bin:/bin` and an executable `$HOME/.local/bin/berth`, the PreToolUse hook command runs `$HOME/.local/bin/berth guard` with the hook's stdin and returns its exit code (2 stays 2: the call is blocked).
- [x] With `berth` on PATH, the PreToolUse hook runs that one, not the one in `~/.local/bin`.
- [x] With no berth anywhere, the PreToolUse hook exits 0 and prints nothing.
- [x] The SessionStart hook, with berth only in `~/.local/bin` and `CLAUDE_ENV_FILE` set, appends `export PATH="$HOME/.local/bin:$PATH"` to that file, prints nothing and exits 0.
- [x] The SessionStart hook, with berth on PATH, writes nothing and prints nothing.
- [x] The SessionStart hook, with no berth anywhere, prints the `systemMessage` JSON line on stdout (it parses as JSON) and exits 0.
- [x] The README and the [[claude-code]] wiki page no longer say the hook does nothing without berth on PATH. They describe the fallback, the PATH export and the warning.
- [x] `swift test` passes, including the new hook tests.

## Implementation

One brick (autopilot, 2026-10-21).
- `claude-plugin/hooks/hooks.json` — PreToolUse: `if command -v berth …; then exec berth guard; elif [ -x "$HOME/.local/bin/berth" ]; then exec "$HOME/.local/bin/berth" guard; fi`. New SessionStart hook, matcher `startup|resume|clear` (compact keeps the session env, so a second append or warning would be noise): berth on PATH → exit 0; only in `~/.local/bin` → `export PATH="$HOME/.local/bin:$PATH"` appended, unexpanded, to `$CLAUDE_ENV_FILE` when set; nowhere → `systemMessage` JSON line.
- `Tests/berthTests/Plugin/HookCommandTests.swift` (new) — runs each hooks.json command with `/bin/sh -c`, temp `HOME`, `PATH=/usr/bin:/bin`, fake `berth` script; 7 cases.
- `Tests/berthTests/Plugin/RepoFile.swift` (new) — repo-file helper shared with `PluginSyncTests`.
- `README.md` l.78 — fallback, PATH export, warning.
- Wiki [[claude-code]] — guard hook section.

Build: `swift build` ✅ · `swift test` ✅ (56 + 83 + 44 + 58 tests, 4 binaries).

## Review

### validation (autopilot) — 2026-10-21
LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓ — verdict clean after 3 autofix rounds.
- Round 1, 6 minor, all fixed: shared `RepoFile` helper instead of copied `root`/`json` [structure]; `Outcome`/`Sandbox` moved into `private extension` [style]; Bool flags renamed `berthOnPath:` / `withEnvFile:` [elegance]; `Sandbox` stores `dir` for cleanup [elegance]; `write(contentsOf:)` instead of legacy `write(Data)` [elegance]; exact warning text asserted + new case "berth in ~/.local/bin, `CLAUDE_ENV_FILE` unset" [correctness].
- Round 2, 1 minor fixed: `RepoFile.url(_:)` private [structure].
- Round 3, 1 minor fixed: member order, private below internal [style].
- Verifier also ran the hook commands under `/bin/sh` and `/bin/zsh` with `env -i`: every branch exits as specified, `exec` passes the guard's exit code through.

## Verification

Runtime check by agent (`env -i HOME=<tmp> PATH=/usr/bin:/bin /bin/sh -c '<hooks.json command>'`, real `.build/debug/berth` linked as `<tmp>/.local/bin/berth`):
- ✅ PreToolUse, `adb shell ls` payload → exit 2, stderr `berth: adb without -s targets whatever device is connected. Claim one: berth run -- <cmd> …`
- ✅ PreToolUse, `ls` payload → exit 0
- ✅ PreToolUse, no berth → exit 0, no output
- ✅ SessionStart, berth only in `~/.local/bin`, `CLAUDE_ENV_FILE` set → exit 0, no stdout, file holds `export PATH="$HOME/.local/bin:$PATH"`
- ✅ SessionStart, no berth → stdout `{"systemMessage": "berth not found on PATH or in ~/.local/bin: the device guard is off. Install: https://github.com/LunabeeStudio/berth#install"}`, exit 0
- ✅ berth on PATH wins over `~/.local/bin`, SessionStart with berth on PATH writes nothing — unit tests
- Not proven by agent: the hooks inside a real Claude Code session (needs a plugin reinstall from this branch and a new session)

## Feedback
