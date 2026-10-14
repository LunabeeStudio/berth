---
issue: 6
phase:
wiki: [[cli]], [[claude-code]] (new), [[index]]
note:
created: 2026-10-14
---

## Context / Decisions

Request (afk autopilot): "setup everything needed to make easy to integrate when coding with Claude (skill? hook?)". Today an agent learns the berth rules only if someone pastes `docs/AGENTS.md` into its `CLAUDE.md`, and nothing stops it from running `adb`, `emulator` or `simctl` on a device it did not claim.

Prior art: Claude Code plugins bundle skills and hooks and install from a git-hosted marketplace (`/plugin marketplace add <owner/repo>`, `/plugin install <name>@<marketplace>`). A `PreToolUse` hook with matcher `Bash` receives the command as JSON on stdin; exit 2 blocks the call and its stderr is fed back to Claude. Nothing in the ecosystem guards emulator/simulator commands, so the guard is custom.

Decisions (all taken unattended by autopilot; each one is tagged and listed in the report for the user to confirm or correct):

- **Delivery = a Claude Code plugin in this repo**, with the marketplace at the repo root: `.claude-plugin/marketplace.json` (marketplace `berth`, one plugin `berth`, `source: "./claude-plugin"`) and the plugin in `claude-plugin/` (`.claude-plugin/plugin.json`, `skills/berth/SKILL.md`, `hooks/hooks.json`). Install = `/plugin marketplace add LunabeeStudio/berth` then `/plugin install berth@berth`. No `berth setup claude` command that edits `~/.claude` files (YAGNI: the plugin system already installs, updates and removes). (autopilot assumption)
- **Skill `berth`** = the agent rules, loaded when a task needs a device. Its description triggers on adb, emulator, Gradle connected tests, simctl, xcodebuild test, devices. Its body is exactly `docs/AGENTS.md` (kept for agents other than Claude Code); a unit test fails when the two drift. (autopilot assumption)
- **Guard hook** = `PreToolUse`, matcher `Bash`, command `command -v berth >/dev/null 2>&1 || exit 0; berth guard` (no berth on PATH → never blocks), timeout 5 s. (autopilot assumption)
- **`berth guard`** = new CLI subcommand: reads the hook payload on stdin, never talks to the daemon. Exit 0 silent = allow. Exit 2 + one stderr line `berth: <why>. <berth alternative>` = deny. Not a `Bash` tool call, unreadable JSON, or a command it cannot parse (unbalanced quotes) → allow: the guard must never break unrelated work (fail open). (autopilot assumption)
- **What is denied** (each simple command of the line, after `;` `&&` `||` `|` `&` newline, `( )`; command word compared by basename, after leading `NAME=value` assignments and the wrappers `env sudo exec time nohup command nice timeout <n> rtk [proxy]`). A segment whose command word is `berth` is always allowed and not inspected further (that is `berth run -- …`). `sh|bash|zsh -c '<script>'` → the script is inspected the same way. (autopilot assumption)
  - `adb` with no target (no `-s <serial>`, no `-t <id>`, no `-d`, no `ANDROID_SERIAL`) → denied, except `devices`, `version`, `help`, `start-server`, `--version`/`-h`/`--help`. `-e` counts as no target (any emulator).
  - `adb kill-server` → always denied (cuts every agent's emulator). `adb … emu kill` → always denied (berth stops emulators).
  - `emulator` and `qemu-system-*` → denied, except `-list-avds`, `-help…`, `-version`, `-accel-check`.
  - `xcrun simctl` (or `simctl`) `boot`, `shutdown`, `erase`, `delete`, `create`, `clone` → denied; any other simctl subcommand with the literal `booted` device argument → denied (it can hit someone else's simulator).
  - `xcodebuild` with a `-destination` that names an iOS simulator by `name=` and has no `id=` → denied (xcodebuild boots it outside berth).
  - Gradle (`gradle`, `gradlew`, any path ending in it) running a `connected…` task (`connectedCheck`, `connectedDebugAndroidTest`, `:app:connected…`) or an `install…` task (`installDebug`, `:app:installRelease`) with no `ANDROID_SERIAL` → denied (it hits every connected device).
  - `pkill` / `killall` whose arguments mention `emulator`, `qemu` or `Simulator` → denied.
- **`ANDROID_SERIAL` counts as set** when it is assigned in front of the command (`ANDROID_SERIAL=$S ./gradlew …`), exported or assigned in an earlier segment of the same line (`export ANDROID_SERIAL=$(berth claim); adb install x`), or present in the hook's own environment. Values are not checked against the daemon (a `$SERIAL` variable cannot be resolved at hook time). (autopilot assumption)
- **No escape hatch flag** (YAGNI): a user who wants raw access disables the plugin's hook. (autopilot assumption)
- **Layout.** CLI code: `Sources/berth/Commands/Guard.swift` (the subcommand) and `Sources/berth/Guard/` (shell tokenizer + rule set, internal). New test target `berthTests` (`Tests/berthTests/Guard/…`, mirrors source, `@testable import berth` like `BerthBarTests`). Plugin files under `claude-plugin/`, marketplace under `.claude-plugin/`. Plugin version `0.1.0`, same as the CLI.
- **Docs.** README: a "Claude Code" section (install the binary, then the two `/plugin` commands; what the skill and the guard do; the guard needs `berth` on PATH). Wiki: new `claude-code` page; `cli` and `index` updated.
- **Out of scope:** hooks for other agents (Codex, Cursor), checking that a literal serial is leased by this session, `SessionEnd` release (leases are already reclaimed when the `claude` process exits), MCP server.

## Acceptance criteria

- `.claude-plugin/marketplace.json` lists one plugin `berth` with source `./claude-plugin`; `claude-plugin/.claude-plugin/plugin.json` declares name `berth`, version `0.1.0`; `claude plugin validate` accepts both (when the installed `claude` has that command).
- A Claude Code session started with `--plugin-dir claude-plugin` lists the `berth` skill and runs `berth guard` before Bash calls: asking it to run `adb shell echo hi` gets the call blocked with berth's reason.
- `berth guard` with a `Bash` PreToolUse payload exits 2 with a one-line `berth: …` stderr naming the berth alternative for each of: `adb install app.apk` · `adb shell pm list packages` · `adb -e shell ls` · `adb kill-server` · `adb -s emulator-5554 emu kill` · `emulator -avd Pixel_9` · `$ANDROID_HOME/emulator/emulator @Pixel_9` · `xcrun simctl boot ABC` · `xcrun simctl shutdown all` · `xcrun simctl install booted App.app` · `./gradlew connectedDebugAndroidTest` · `./gradlew :app:installDebug` · `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 17'` · `pkill -f qemu` · `git status && adb logcat` · `sh -c 'adb install app.apk'`.
- `berth guard` exits 0 with no output for each of: `berth run -- ./gradlew connectedDebugAndroidTest` · `berth run -- sh -c 'adb install app.apk'` · `adb -s "$SERIAL" install app.apk` · `ANDROID_SERIAL=$S ./gradlew connectedDebugAndroidTest` · `export ANDROID_SERIAL=$(berth claim); adb install app.apk` · `adb devices` · `emulator -list-avds` · `xcrun simctl list devices` · `xcrun simctl install "$UDID" App.app` · `xcodebuild test -destination "id=$SIMULATOR_UDID"` · `./gradlew assembleDebug` · `grep -r adb README.md` · `echo "adb install app.apk"` · a non-Bash tool payload · malformed JSON · a command with an unbalanced quote.
- `berth guard` exits 0 for `adb install app.apk` when `ANDROID_SERIAL` is set in its own environment.
- `berth --help` lists `guard`.
- README has a Claude Code section with the install commands; the skill body equals `docs/AGENTS.md` and a unit test fails when they differ.
- `swift build` and `swift test` pass; unit tests cover the tokenizer (quotes, escapes, operators, `-c` scripts) and every allow/deny case above.
