# Claude Code integration

Plugin in repo. Marketplace `.claude-plugin/marketplace.json` (marketplace `berth`, plugin `berth`, `source: ./claude-plugin`). Install: `/plugin marketplace add LunabeeStudio/berth` → `/plugin install berth@berth`. Plugin ships no binary: hooks find it on PATH, else at `~/.local/bin/berth` (install.sh default).

```
claude-plugin/
├── .claude-plugin/plugin.json   # name berth, version = CLI version
├── skills/berth/SKILL.md        # agent rules, body == docs/AGENTS.md
└── hooks/hooks.json             # SessionStart → PATH export / warning; PreToolUse, matcher Bash → berth guard
```

## Skill
Description triggers on adb, emulator, Gradle connected/install, simctl, xcodebuild test, UI tests, device screenshots, human action on device (login, sign-in, 2FA, captcha, show emulator/simulator window). Body section "When a human must act on the device": `berth claim` (not `run`: releases at end) → `berth mirror "$SERIAL"` → tell user what to do → wait for reply → continue; `renew` if long. Body byte-identical to `docs/AGENTS.md` after frontmatter + blank line (other agents still paste AGENTS.md). `PluginSyncTests` fails on drift, also when plugin.json / marketplace.json version ≠ `Berth.configuration.version` → bump all three together.

## Guard hook
Both hooks inline POSIX `sh` in `hooks.json`, timeout 5 s, resolve berth: `command -v berth`, else `$HOME/.local/bin/berth` if executable (#34: install dir often missing from the PATH Claude Code inherits → guard used to exit 0 silently, agents ran `adb`/`emulator` unguarded).
- **PreToolUse** (matcher `Bash`) → `exec <berth> guard`. No berth anywhere → exit 0, silent, never blocks.
- **SessionStart** (matcher `startup|resume|clear`; compact keeps session env) → berth on PATH: nothing. Only in `~/.local/bin`: append `export PATH="$HOME/.local/bin:$PATH"` (unexpanded) to `$CLAUDE_ENV_FILE` so agent Bash calls (skill commands, guard hints) find `berth`. Nowhere: one stdout JSON line `{"systemMessage": "berth not found … device guard is off …"}`, exit 0 — warning once per session, not per Bash call.
- `HookCommandTests` runs each command from `hooks.json` via `/bin/sh -c` with temp `HOME`, `PATH=/usr/bin:/bin`, fake `berth` script.

`berth guard` (CLI only, never talks to daemon): stdin payload → `HookPayload.command(from:)` (nil unless `tool_name == Bash`) → `DeviceCommandGuard.verdict(for:)`. Allow = exit 0 silent. Deny = exit 2 + one stderr line `berth: <why>. <berth alternative>` (Claude Code feeds stderr back to model).

**Fail open**: unreadable JSON, non-Bash tool, unparseable line (unbalanced quote, unterminated heredoc) → allow. Guard must never break unrelated work.

### Parsing (`Sources/berth/Guard/`)
- `ShellTokenizer.commands(of:)` → `[ShellCommand]` (words, heredoc body, `isPiped`). Private `Lexer` with cursor: quotes, escapes, operators `; && || | & newline ( ) $(`, `#` comments, heredoc `<<`/`<<-` (body skipped from words, kept on owning command), no heredoc inside `((`/`$((`.
- `SimpleCommand`: strips `NAME=value` assignments, keywords (`if then do else elif while until ! { for…`), wrappers from `Wrapper` table (`env sudo exec time nohup nice timeout xargs xcrun rtk [proxy] command`, with their value options). `command -v/-V` = lookup → no command word. Command word compared by basename.
- `DeviceCommandGuard`: `berth …` segment → allowed, not inspected (`berth run -- …`). `sh|bash|zsh` with a `-c` cluster (`-lc`) → script judged recursively; bare shell fed by heredoc (own or previous pipe stage) → body judged. `export ANDROID_SERIAL=…` / bare assignment persists to later segments. Rules injected (`init(environment:rules:)`, default `defaultRules`).

### Rules (`Guard/Rules/`, one `DeviceCommandRule` per tool, nil = not mine)
- `AdbRule` — no target (`-s`, `-t`, `-d`, `ANDROID_SERIAL`) → deny, except devices/version/help/start-server. `-e` = no target. `kill-server`, `emu kill` → always deny.
- `EmulatorRule` — `emulator`, `qemu-system-*` → deny, except `-list-avds`, `-version`, `-accel-check`, `-help…`.
- `SimctlRule` — boot/shutdown/erase/delete/create/clone → deny; literal `booted` → deny except `list`/`help`.
- `XcodebuildRule` — `-destination` with iOS Simulator `name=` and no `id=` → deny.
- `GradleRule` — `connected…` / `install…` task (last `:` segment; not `installDist`; option values like `--tests X` skipped) without `ANDROID_SERIAL` → deny. Install hint (wins on mixed): `assemble…` + `SERIAL=$(berth claim)` + `adb -s "$SERIAL" install -r <apk>` (BERTH-3: AGP install goes through ddmlib, can restart shared adb server); connected-only hint: `berth run -- ./gradlew …`. With `ANDROID_SERIAL` both still allowed.
- `ProcessKillRule` — `pkill`/`killall` mentioning emulator/qemu/simulator → deny.
- `ScrcpyRule` — `scrcpy` → deny (uses adb on PATH, can restart shared adb server), hint `berth mirror <serial>`; `--version`/`-v`/`--help`/`-h` allowed.

Hints for iOS use `berth run --ios -- sh -c '… "$SIMULATOR_UDID" …'`: outer shell would expand var empty before berth sets it.

### Limits
Serial values never checked against daemon leases (`$SERIAL` unresolvable at hook time). Heuristic, not a shell: `eval`, aliases, functions, scripts on disk not inspected. No escape hatch: disable plugin to opt out.
