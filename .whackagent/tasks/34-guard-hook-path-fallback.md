---
issue: 34
phase:
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

- [ ] With `PATH=/usr/bin:/bin` and an executable `$HOME/.local/bin/berth`, the PreToolUse hook command runs `$HOME/.local/bin/berth guard` with the hook's stdin and returns its exit code (2 stays 2: the call is blocked).
- [ ] With `berth` on PATH, the PreToolUse hook runs that one, not the one in `~/.local/bin`.
- [ ] With no berth anywhere, the PreToolUse hook exits 0 and prints nothing.
- [ ] The SessionStart hook, with berth only in `~/.local/bin` and `CLAUDE_ENV_FILE` set, appends `export PATH="$HOME/.local/bin:$PATH"` to that file, prints nothing and exits 0.
- [ ] The SessionStart hook, with berth on PATH, writes nothing and prints nothing.
- [ ] The SessionStart hook, with no berth anywhere, prints the `systemMessage` JSON line on stdout (it parses as JSON) and exits 0.
- [ ] The README and the [[claude-code]] wiki page no longer say the hook does nothing without berth on PATH. They describe the fallback, the PATH export and the warning.
- [ ] `swift test` passes, including the new hook tests.

## Implementation

## Review

## Verification

## Feedback
